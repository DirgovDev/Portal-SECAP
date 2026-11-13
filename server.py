"""SECAP web server — Supabase Local Edition. Python 3.10+, standard library only."""

import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
PUBLIC_DIR = ROOT / 'public'


class Handler(SimpleHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PUBLIC_DIR), **kwargs)

    def end_headers(self):
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Referrer-Policy', 'same-origin')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def reply_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path.startswith('/api/'):
            return self.reply_json(404, {
                'error': 'As requisições da API do SECAP são gerenciadas diretamente pelo Supabase CLI local (porta 54321).'
            })
        super().do_GET()

    def do_POST(self):
        self.reply_json(404, {
            'error': 'As requisições da API do SECAP são gerenciadas diretamente pelo Supabase CLI local (porta 54321).'
        })


if __name__ == '__main__':
    host = os.environ.get('SECAP_HOST', '127.0.0.1')
    port = int(os.environ.get('SECAP_PORT', '8080'))
    print(f'SECAP Portal disponível em http://{host}:{port}')
    print(f'Backend / Banco de Dados: Supabase CLI Local em http://127.0.0.1:54321')
    print('Pressione Ctrl+C para encerrar.', flush=True)
    ThreadingHTTPServer((host, port), Handler).serve_forever()
