"""Copia o SQLite local para o Supabase.

A senha PBKDF2 do servidor local não entra no Supabase Auth. O script cria
(ou reutiliza e atualiza) o administrador com SECAP_ADMIN_PASSWORD e envia o estado,
a agenda e as solicitações. A service_role fica só neste processo.

Variáveis, no ambiente ou em .env na raiz do projeto:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SECAP_ADMIN_PASSWORD
"""
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / 'data' / 'secap.sqlite3'


def load_env():
    path = ROOT / '.env'
    if not path.exists():
        return
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def api(method, url, key, payload=None, prefer=None):
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode('utf-8')
    headers = {
        'apikey': key,
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json',
    }
    if prefer:
        headers['Prefer'] = prefer
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read().decode('utf-8')
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', errors='replace')
        raise SystemExit(f'{method} {url} falhou ({error.code}): {detail}') from error


def find_user(base, key, email):
    page = 1
    while True:
        _, body = api('GET', f'{base}/auth/v1/admin/users?page={page}&per_page=200', key)
        users = (body or {}).get('users') or []
        for user in users:
            if (user.get('email') or '').lower() == email:
                return user['id']
        if len(users) < 200:
            return ''
        page += 1
        if page > 20:
            return ''


def iso_from_unix(value):
    if isinstance(value, str) and 'T' in value:
        return value
    return datetime.fromtimestamp(float(value), timezone.utc).isoformat()


def copy_modernization(base, key):
    """Substitui as solicitações de modernização do Supabase pelas do SQLite (com histórico e sequência)."""
    with sqlite3.connect(DB) as db:
        db.row_factory = sqlite3.Row
        table_name = None
        for candidate in ['modernization_requests', 'local_mod_requests']:
            if db.execute("select 1 from sqlite_master where type = 'table' and name = ?", (candidate,)).fetchone():
                table_name = candidate
                break

        if not table_name:
            print('O SQLite não tem solicitações de modernização; nada a copiar.')
            return

        hist_table = 'modernization_history' if table_name == 'modernization_requests' else 'local_mod_history'
        
        raw_reqs = db.execute(f'select * from {table_name}').fetchall()
        raw_hist = []
        if db.execute("select 1 from sqlite_master where type = 'table' and name = ?", (hist_table,)).fetchone():
            raw_hist = db.execute(f'select * from {hist_table}').fetchall()

    if not raw_reqs:
        print('Nenhuma solicitação de modernização no SQLite.')
        return

    requests = []
    for r in raw_reqs:
        d = dict(r)
        if 'body' in d and isinstance(d['body'], str):
            b = json.loads(d['body'])
            b['protocol'] = d.get('protocol', b.get('protocol'))
            requests.append(b)
        else:
            requests.append(d)

    history = []
    for h in raw_hist:
        d = dict(h)
        if 'body' in d and isinstance(d['body'], str):
            b = json.loads(d['body'])
            b['protocol'] = d.get('protocol', b.get('protocol'))
            history.append(b)
        else:
            history.append(d)

    request_rows = [
        {
            'protocol': r['protocol'],
            'created_at': iso_from_unix(r['created_at']),
            'requester_email': r['requester_email'].lower(),
            'requester_name': r['requester_name'],
            'registration': r['registration'],
            'department': r['department'],
            'solution_type': r['solution_type'],
            'title': r['title'],
            'description': r['description'],
            'status': r['status'],
            'updated_at': iso_from_unix(r.get('updated_at', r['created_at'])),
            'updated_by': r.get('updated_by', r['requester_name']),
            'rating': r.get('rating'),
            'rating_label': r.get('rating_label'),
            'rating_comment': r.get('rating_comment'),
        }
        for r in requests
    ]
    history_rows = [
        {
            'protocol': h['protocol'],
            'created_at': iso_from_unix(h['created_at']),
            'event': h['event'],
            'previous_status': h.get('previous_status'),
            'new_status': h.get('new_status'),
            'actor_email': h['actor_email'],
            'actor_name': h['actor_name'],
            'note': h.get('note'),
        }
        for h in history
    ]
    seq = {}
    for r in requests:
        parts = r['protocol'].split('-')
        if len(parts) == 3 and parts[1].isdigit() and parts[2].isdigit():
            seq[int(parts[1])] = max(seq.get(int(parts[1]), 0), int(parts[2]))

    api('DELETE', f'{base}/rest/v1/modernization_requests?protocol=not.is.null', key)
    api('DELETE', f'{base}/rest/v1/modernization_seq?year=not.is.null', key)
    for start in range(0, len(request_rows), 200):
        api('POST', f'{base}/rest/v1/modernization_requests', key, request_rows[start:start + 200], 'return=minimal')
    for start in range(0, len(history_rows), 200):
        api('POST', f'{base}/rest/v1/modernization_history', key, history_rows[start:start + 200], 'return=minimal')
    if seq:
        api(
            'POST',
            f'{base}/rest/v1/modernization_seq',
            key,
            [{'year': y, 'last': n} for y, n in seq.items()],
            'resolution=merge-duplicates,return=minimal',
        )
    print(f'Solicitações de modernização enviadas: {len(request_rows)} (histórico: {len(history_rows)}).')


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    load_env()
    base = os.environ.get('SUPABASE_URL', '').rstrip('/')
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
    password = os.environ.get('SECAP_ADMIN_PASSWORD', '')
    if not base or not key:
        raise SystemExit('Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.')
    if not DB.exists():
        raise SystemExit(f'Banco não encontrado: {DB}')
    if key.startswith('eyJ'):
        try:
            part = key.split('.')[1]
            pad = '=' * (-len(part) % 4)
            role = json.loads(__import__('base64').urlsafe_b64decode(part + pad)).get('role')
        except Exception:
            role = ''
        if role and role != 'service_role':
            raise SystemExit('SUPABASE_SERVICE_ROLE_KEY precisa ser a chave service_role.')

    with sqlite3.connect(DB) as db:
        auth = db.execute('select email from auth where id = 1').fetchone()
        state = db.execute('select body from state where id = 1').fetchone()
        agenda = db.execute('select id, body from calendar_items').fetchall() if auth else []
        requests = db.execute(
            'select name, email, job_title, created_at, status from account_requests'
        ).fetchall()

    if not auth:
        raise SystemExit('O SQLite ainda não tem administrador. Entre no portal local antes de importar.')
    email = auth[0].strip().lower()
    user_id = find_user(base, key, email)
    if not user_id:
        if len(password) < 12:
            raise SystemExit('Defina SECAP_ADMIN_PASSWORD com pelo menos 12 caracteres para criar o administrador na nuvem.')
        _, created = api(
            'POST',
            f'{base}/auth/v1/admin/users',
            key,
            {'email': email, 'password': password, 'email_confirm': True},
        )
        user_id = created['id']
        print(f'Administrador {email} criado no Supabase com sucesso.')
    else:
        print(f'Administrador {email} já existia no Supabase.')
        if len(password) >= 12:
            api(
                'PUT',
                f'{base}/auth/v1/admin/users/{user_id}',
                key,
                {'password': password, 'email_confirm': True},
            )
            print('Senha do administrador atualizada no Supabase conforme SECAP_ADMIN_PASSWORD.')

    api(
        'POST',
        f'{base}/rest/v1/profiles',
        key,
        [{'id': user_id, 'email': email, 'role': 'administrador'}],
        'resolution=merge-duplicates,return=minimal',
    )

    if state and state[0]:
        api(
            'POST',
            f'{base}/rest/v1/app_state',
            key,
            [{'id': 1, 'body': json.loads(state[0])}],
            'resolution=merge-duplicates,return=minimal',
        )
        print('Estado do portal enviado do SQLite para o Supabase com sucesso.')
    else:
        print('Nenhum estado gravado no SQLite.')

    api('DELETE', f'{base}/rest/v1/calendar_items?owner=eq.{user_id}', key)
    rows = [{'id': item_id, 'owner': user_id, 'body': json.loads(body)} for item_id, body in agenda]
    for start in range(0, len(rows), 200):
        api('POST', f'{base}/rest/v1/calendar_items', key, rows[start:start + 200])
    if rows:
        print(f'Agenda enviada: {len(rows)} compromisso(s).')

    sent = 0
    allowed_status = {'Pendente', 'Aprovada', 'Recusada'}
    for name, request_email, job_title, created_at, status in requests:
        try:
            api(
                'POST',
                f'{base}/rest/v1/account_requests',
                key,
                [{
                    'name': name,
                    'email': request_email,
                    'job_title': job_title,
                    'created_at': iso_from_unix(created_at or 0),
                    'status': status if status in allowed_status else 'Pendente',
                }],
                'return=minimal',
            )
            sent += 1
        except SystemExit as error:
            if '23505' in str(error) or 'duplicate' in str(error).lower():
                continue
            raise
    if sent:
        print(f'Solicitações de conta enviadas: {sent}.')

    copy_modernization(base, key)
    print('Importação concluída com sucesso para o Supabase Local!')


if __name__ == '__main__':
    main()
