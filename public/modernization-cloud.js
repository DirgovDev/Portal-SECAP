// Solicitações de modernização no modo Supabase.
// O navegador continua chamando /api/modernization/*; supabase-boot.js encaminha para cá.
// Leitura direta (RLS: só o administrador). Escrita somente pelas funções mod_* da migração
// 20261109120000_modernization.sql, que aplicam as regras e gravam o histórico em uma transação.

const PROTOCOL = /^SECAP-\d{4}-\d{5,}$/;

function json(status, obj) {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json' } });
}

function failure(error) {
  const message = error?.message || 'Falha ao gravar no Supabase.';
  let status = 400;
  if (/Acesso restrito/.test(message)) status = 403;
  else if (/alterada enquanto/.test(message)) status = 409;
  else if (/n[ãa]o encontrada/i.test(message)) status = 404;
  else if (error?.code === 'PGRST202' || error?.code === '42883' || error?.code === '42P01') {
    return json(500, {
      error: 'As solicitações ainda não existem no Supabase. Execute supabase/migrations/20261109120000_modernization.sql.',
    });
  }
  return json(status, { error: message });
}

export async function exportModernization(sb) {
  const requests = await sb.from('modernization_requests').select('*').order('created_at', { ascending: false });
  if (requests.error) throw new Error(requests.error.message);
  const history = await sb.from('modernization_history').select('*').order('created_at', { ascending: true }).order('id', { ascending: true });
  if (history.error) throw new Error(history.error.message);
  return { requests: requests.data || [], history: history.data || [] };
}

export function validModernizationBackup(mod) {
  return (
    !!mod &&
    typeof mod === 'object' &&
    Array.isArray(mod.requests) &&
    (mod.history === undefined || Array.isArray(mod.history)) &&
    mod.requests.every((r) => r && typeof r === 'object' && PROTOCOL.test(String(r.protocol || '').toUpperCase()))
  );
}

export async function replaceModernization(sb, mod) {
  const { error } = await sb.rpc('mod_import', {
    p_requests: mod.requests,
    p_history: mod.history || [],
    p_replace: true,
  });
  return error || null;
}

export async function handleModernization(sb, path, method, search, body) {
  try {
    if (path === '/api/modernization/requests' && method === 'GET') {
      const { data, error } = await sb
        .from('modernization_requests')
        .select('*')
        .order('created_at', { ascending: false })
        .order('protocol', { ascending: false });
      if (error) return failure(error);
      return json(200, { requests: data || [] });
    }
    if (path === '/api/modernization/request' && method === 'GET') {
      const protocol = String(new URLSearchParams(search || '').get('protocol') || '').trim().toUpperCase();
      if (!PROTOCOL.test(protocol)) return json(400, { error: 'Protocolo inválido. Use o formato SECAP-AAAA-NNNNN.' });
      const request = await sb.from('modernization_requests').select('*').eq('protocol', protocol).maybeSingle();
      if (request.error) return failure(request.error);
      if (!request.data) return json(404, { error: 'Solicitação não encontrada. Atualize a lista e tente novamente.' });
      const history = await sb
        .from('modernization_history')
        .select('*')
        .eq('protocol', protocol)
        .order('created_at', { ascending: true })
        .order('id', { ascending: true });
      if (history.error) return failure(history.error);
      return json(200, { request: request.data, history: history.data || [] });
    }
    if (method !== 'POST') return json(404, { error: 'Rota não encontrada.' });
    const data = body && typeof body === 'object' ? body : {};
    if (path === '/api/modernization/create') {
      const { data: out, error } = await sb.rpc('mod_create_request', { p: data });
      return error ? failure(error) : json(201, out);
    }
    if (path === '/api/modernization/status') {
      const { data: out, error } = await sb.rpc('mod_change_status', {
        p_protocol: String(data.protocol || ''),
        p_new: String(data.new_status || ''),
        p_expected: data.expected_status ? String(data.expected_status) : null,
        p_note: String(data.note || ''),
      });
      return error ? failure(error) : json(200, out);
    }
    if (path === '/api/modernization/rating') {
      const { data: out, error } = await sb.rpc('mod_rate_request', {
        p_protocol: String(data.protocol || ''),
        p_rating: Number.isInteger(Number(data.rating)) ? Number(data.rating) : null,
        p_comment: String(data.comment || ''),
      });
      return error ? failure(error) : json(200, out);
    }
    if (path === '/api/modernization/import') {
      if (!Array.isArray(data.requests)) return json(400, { error: 'Solicitações inválidas.' });
      const { data: count, error } = await sb.rpc('mod_import', {
        p_requests: data.requests,
        p_history: Array.isArray(data.history) ? data.history : [],
        p_replace: false,
      });
      return error ? failure(error) : json(200, { imported: count });
    }
    return json(404, { error: 'Rota não encontrada.' });
  } catch (error) {
    return failure(error);
  }
}
