-- SECAP: sincroniza as migrações com o banco local em uso.
--
-- Gerado com `supabase db diff` (banco local x migrações anteriores) em 17/11/2026.
-- Reúne o que antes era aplicado manualmente pelo SQL Editor:
--   * supabase/security/project_access.sql  (acesso por projeto, secap_member_state, guards de obras)
--   * supabase/security/audit_admin.sql     (auditoria paginada, recuperação, nome do autor)
--   * secap_set_user_role, obra_section_configs e user_custom_dashboards (criados direto no banco)
--
-- No banco que JÁ tinha esses scripts, esta migração é apenas marcada como aplicada
-- (supabase migration repair --status applied 20261117120000). Em um banco novo
-- (supabase db reset / start), ela recria tudo a partir das migrações.

SET local check_function_bodies = off;

DROP POLICY "app_state_member_insert" ON "public"."app_state";

DROP POLICY "app_state_member_read" ON "public"."app_state";

DROP POLICY "app_state_member_update" ON "public"."app_state";

DROP POLICY "obras_delete" ON "public"."obras";

DROP POLICY "obras_insert" ON "public"."obras";

DROP POLICY "obras_select" ON "public"."obras";

DROP POLICY "obras_update" ON "public"."obras";

DROP POLICY "planilhas_delete" ON "public"."planilhas_importadas";

DROP POLICY "planilhas_insert" ON "public"."planilhas_importadas";

DROP POLICY "planilhas_select" ON "public"."planilhas_importadas";

CREATE SCHEMA "secap_private";

CREATE TABLE "public"."obra_section_configs" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "section_key"   text                     NOT NULL,
  "section_title" text                     NOT NULL,
  "fields"        jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "updated_at"    timestamp with time zone DEFAULT now(),
  "updated_by"    uuid,
  CONSTRAINT "obra_section_configs_pkey" PRIMARY KEY (id),
  CONSTRAINT "obra_section_configs_section_key_key" UNIQUE (section_key)
);

ALTER TABLE "public"."obra_section_configs"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."secap_audit_events" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "at"             timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
  "actor"          uuid,
  "who"            text                     NOT NULL,
  "project_id"     text                     NOT NULL,
  "project_name"   text                     NOT NULL,
  "record_id"      text                     NOT NULL,
  "record_name"    text                     NOT NULL,
  "field_id"       text                     NOT NULL,
  "field_name"     text                     NOT NULL,
  "before_value"   jsonb,
  "after_value"    jsonb,
  "before_present" boolean                  NOT NULL,
  "after_present"  boolean                  NOT NULL,
  "action"         text                     NOT NULL DEFAULT 'Alterou campo'::text,
  "recovered_from" uuid,
  CONSTRAINT "secap_audit_events_pkey" PRIMARY KEY (id),
  CONSTRAINT "secap_audit_events_recovered_from_key" UNIQUE (recovered_from)
);

ALTER TABLE "public"."secap_audit_events"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."secap_audit_events" FROM "anon";

CREATE TABLE "public"."secap_audit_legacy" (
  "id"    text                     NOT NULL,
  "at"    timestamp with time zone NOT NULL,
  "entry" jsonb                    NOT NULL,
  CONSTRAINT "secap_audit_legacy_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."secap_audit_legacy"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."secap_audit_legacy" FROM "anon";

CREATE TABLE "public"."secap_member_state" (
  "owner" uuid  NOT NULL,
  "body"  jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT "secap_member_state_pkey" PRIMARY KEY (OWNER)
);

ALTER TABLE "public"."secap_member_state"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."secap_member_state" FROM "anon", "authenticated";

CREATE TABLE "public"."user_custom_dashboards" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"          uuid                     NOT NULL,
  "subtab_id"        character varying(50)    NOT NULL,
  "dashboard_config" jsonb                    NOT NULL DEFAULT '{"widgets": []}'::jsonb,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "user_custom_dashboards_pkey" PRIMARY KEY (id),
  CONSTRAINT "user_custom_dashboards_user_id_subtab_id_key" UNIQUE (user_id, subtab_id)
);

ALTER TABLE "public"."user_custom_dashboards"
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles"
  ADD COLUMN "project_scope" text NOT NULL DEFAULT 'selected'::text;

ALTER TABLE "public"."profiles"
  ADD COLUMN "project_ids" text[] NOT NULL DEFAULT '{}'::text[];

CREATE OR REPLACE FUNCTION public.guard_obras_delete_permissions()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  member_email text;
  allowed_fields jsonb;
begin
  if auth.uid() is null or public.is_admin() then
    return old;
  end if;

  select lower(p.email) into member_email
    from public.profiles p
   where p.id = auth.uid() and p.role = 'usuario';
  if member_email is null then
    raise exception 'Usuário não autorizado.' using errcode = '42501';
  end if;

  select s.body->'fieldPermissions'->member_email->old.project_id into allowed_fields
    from public.app_state s
   where s.id = 1;

  if allowed_fields is null or jsonb_typeof(allowed_fields) <> 'array'
     or jsonb_array_length(allowed_fields) = 0 then
    raise exception 'Nenhum campo foi liberado para edição neste projeto.' using errcode = '42501';
  end if;
  return old;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."guard_obras_delete_permissions"() FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.guard_obras_field_permissions()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  member_email text;
  allowed_fields jsonb := '[]'::jsonb;
  field_id text;
  old_keys text[];
  new_keys text[];
  changed_keys text[];
  new_value jsonb;
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  select lower(p.email) into member_email
    from public.profiles p
   where p.id = auth.uid() and p.role = 'usuario';

  if member_email is null then
    raise exception 'Usuário não autorizado.' using errcode = '42501';
  end if;

  select coalesce(
    s.body->'fieldPermissions'->member_email->new.project_id,
    '[]'::jsonb
  ) into allowed_fields
    from public.app_state s
   where s.id = 1;

  -- Sem linha em app_state o SELECT acima devolve NULL; NULL nunca pode virar liberação.
  if allowed_fields is null or jsonb_typeof(allowed_fields) <> 'array' then
    allowed_fields := '[]'::jsonb;
  end if;

  if tg_op = 'INSERT' then
    if jsonb_array_length(allowed_fields) = 0 then
      raise exception 'Nenhum campo foi liberado para edição neste projeto.' using errcode = '42501';
    end if;

    -- Campos padrão: valores diferentes dos padrões só podem ser enviados se liberados.
    if new.nome is distinct from '' and not (allowed_fields ? 'nome') then
      raise exception 'Sem permissão para editar o campo nome.' using errcode = '42501';
    end if;
    if new.status is distinct from 'Planejamento' and not (allowed_fields ? 'status') then
      raise exception 'Sem permissão para editar o campo status.' using errcode = '42501';
    end if;
    if new.valor is not null and not (allowed_fields ? 'valor') then
      raise exception 'Sem permissão para editar o campo valor.' using errcode = '42501';
    end if;
    if new.executado is not null and not (allowed_fields ? 'executado') then
      raise exception 'Sem permissão para editar o campo executado.' using errcode = '42501';
    end if;
    if new.prazo is not null and not (allowed_fields ? 'prazo') then
      raise exception 'Sem permissão para editar o campo prazo.' using errcode = '42501';
    end if;
    if new.responsavel is distinct from '' and not (allowed_fields ? 'responsavel') then
      raise exception 'Sem permissão para editar o campo responsavel.' using errcode = '42501';
    end if;
    if coalesce(new.progresso, 0) <> 0 and not (allowed_fields ? 'progresso') then
      raise exception 'Sem permissão para editar o campo progresso.' using errcode = '42501';
    end if;
    if new.proxima is distinct from '' and not (allowed_fields ? 'proxima') then
      raise exception 'Sem permissão para editar o campo proxima.' using errcode = '42501';
    end if;
    if new.orgao is distinct from '' and not (allowed_fields ? 'orgao') then
      raise exception 'Sem permissão para editar o campo orgao.' using errcode = '42501';
    end if;

    -- Campos personalizados são armazenados no objeto JSONB dados.
    for field_id, new_value in select key, value from jsonb_each(coalesce(new.dados, '{}'::jsonb)) loop
      if new_value is distinct from 'null'::jsonb
         and new_value is distinct from '""'::jsonb
         and not (allowed_fields ? field_id) then
        raise exception 'Sem permissão para editar o campo personalizado %.', field_id using errcode = '42501';
      end if;
    end loop;

    if coalesce(new.nome_planilha, '') <> '' or new.planilha_id is not null then
      raise exception 'Somente o administrador pode importar planilhas.' using errcode = '42501';
    end if;
    return new;
  end if;

  -- Impede mover ou trocar a identidade/origem da obra por uma atualização de campo.
  if new.id is distinct from old.id or new.project_id is distinct from old.project_id
     or new.nome_planilha is distinct from old.nome_planilha
     or new.planilha_id is distinct from old.planilha_id then
    raise exception 'Não é permitido alterar a identificação ou a origem da obra.' using errcode = '42501';
  end if;

  foreach field_id in array array['nome','status','valor','executado','prazo','responsavel','progresso','proxima','orgao'] loop
    if (to_jsonb(old)->field_id) is distinct from (to_jsonb(new)->field_id)
       and not (allowed_fields ? field_id) then
      raise exception 'Sem permissão para editar o campo %.', field_id using errcode = '42501';
    end if;
  end loop;

  select coalesce(array_agg(key), '{}'::text[]) into old_keys
    from jsonb_object_keys(coalesce(old.dados, '{}'::jsonb)) as keys(key);
  select coalesce(array_agg(key), '{}'::text[]) into new_keys
    from jsonb_object_keys(coalesce(new.dados, '{}'::jsonb)) as keys(key);
  select coalesce(array_agg(distinct field_key), '{}'::text[]) into changed_keys
    from unnest(old_keys || new_keys) as changed(field_key);
  foreach field_id in array changed_keys loop
    if (old.dados->field_id) is distinct from (new.dados->field_id)
       and not (allowed_fields ? field_id) then
      raise exception 'Sem permissão para editar o campo personalizado %.', field_id using errcode = '42501';
    end if;
  end loop;

  return new;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."guard_obras_field_permissions"() FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.secap_audit_logs()
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare result jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Auditoria disponível apenas para administradores.' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(entry order by entry->>'at' desc), '[]'::jsonb) into result
  from (
    select distinct entry from (
      select jsonb_build_object('id','server:'||e.id::text,'eventId',e.id,'at',e.at,'who',case when position('@' in e.who)>0 or btrim(e.who) in ('','Nome não informado','Usuário não informado') then secap_private.audit_actor_name(e.actor,e.who) else e.who end,'action',e.action,
        'project',e.project_id,'projectName',e.project_name,'recordId',e.record_id,'recordName',e.record_name,
        'field',e.field_name,'fieldId',e.field_id,'before',e.before_value,'after',e.after_value,
        'recoveredFrom',e.recovered_from,
        'recovered',exists(select 1 from public.secap_audit_events recovery where recovery.recovered_from=e.id),
        'recoverable',not exists(select 1 from public.secap_audit_events recovery where recovery.recovered_from=e.id)) as entry
      from public.secap_audit_events e
      union all
      select l.value as entry from public.app_state s
      cross join lateral jsonb_array_elements(coalesce(s.body->'logs','[]'::jsonb)) l
      where s.id=1
      union all
      select l.value || jsonb_build_object('user',m.owner::text,
        'who',secap_private.audit_actor_name(m.owner,p.email)) as entry
      from public.secap_member_state m
      left join public.profiles p on p.id=m.owner
      cross join lateral jsonb_array_elements(coalesce(m.body->'logs','[]'::jsonb)) l
    ) entries
  ) unique_entries;
  return result;
end $function$;

REVOKE ALL ON FUNCTION "public"."secap_audit_logs"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_audit_page (
  p_view        text                     DEFAULT 'recent'::text,
  p_start       date                     DEFAULT NULL::date,
  p_end         date                     DEFAULT NULL::date,
  p_before_at   timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_before_id   text                     DEFAULT NULL::text,
  p_archive_end date                     DEFAULT NULL::date
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare first_day date; last_day date; cutoff date; lower_at timestamptz; upper_at timestamptz;
 selected_lower timestamptz; selected_upper timestamptz; available_start timestamptz; available_end timestamptz;
 page_rows jsonb; has_more boolean; tail jsonb;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Auditoria restrita aos administradores.' using errcode='42501';end if;
 if p_view not in ('recent','archive') or p_view is null then raise exception 'Período inválido.';end if;
 cutoff := (current_timestamp at time zone 'America/Sao_Paulo')::date-39;
 if p_view='recent' then first_day:=cutoff;last_day:=cutoff+39;
 else last_day:=least(coalesce(p_archive_end,cutoff-1),cutoff-1);first_day:=last_day-39;end if;
 if (p_start is null) <> (p_end is null) or p_start>p_end then raise exception 'Intervalo de datas inválido.';end if;
 if (p_before_at is null) <> (p_before_id is null) then raise exception 'Página inválida.';end if;
 lower_at := first_day::timestamp at time zone 'America/Sao_Paulo';
 upper_at := (last_day+1)::timestamp at time zone 'America/Sao_Paulo';
 selected_lower:=greatest(lower_at,coalesce(p_start::timestamp at time zone 'America/Sao_Paulo',lower_at));
 selected_upper:=least(upper_at,coalesce((p_end+1)::timestamp at time zone 'America/Sao_Paulo',upper_at));
 select min(stamp),max(stamp) into available_start,available_end from (
  select min(at) as stamp from public.secap_audit_events where at>=lower_at and at<upper_at union all
  select max(at) from public.secap_audit_events where at>=lower_at and at<upper_at union all
  select min(at) from public.secap_audit_legacy where at>=lower_at and at<upper_at union all
  select max(at) from public.secap_audit_legacy where at>=lower_at and at<upper_at
 ) bounds;
 with candidates as (
  (select e.at,'server:'||e.id::text as sort_id,jsonb_build_object('id','server:'||e.id::text,'eventId',e.id,'at',e.at,'who',case when position('@' in e.who)>0 or btrim(e.who) in ('','Nome não informado','Usuário não informado') then secap_private.audit_actor_name(e.actor,e.who) else e.who end,'action',e.action,
   'project',e.project_id,'projectName',e.project_name,'recordId',e.record_id,'recordName',e.record_name,'field',e.field_name,'fieldId',e.field_id,
   'before',e.before_value,'after',e.after_value,'recoveredFrom',e.recovered_from,
   'recovered',exists(select 1 from public.secap_audit_events r where r.recovered_from=e.id),
   'recoverable',not exists(select 1 from public.secap_audit_events r where r.recovered_from=e.id)) as entry
   from public.secap_audit_events e where e.at>=selected_lower and e.at<selected_upper
   and (p_before_at is null or (e.at,'server:'||e.id::text)<(p_before_at,p_before_id)) order by e.at desc,e.id desc limit 51)
  union all
  (select l.at,'legacy:'||l.id,l.entry || jsonb_build_object('id','legacy:'||l.id,'at',l.at,'recoverable',false,'eventId',null,'who',secap_private.audit_entry_name(l.entry)) from public.secap_audit_legacy l
   where l.at>=selected_lower and l.at<selected_upper
   and (p_before_at is null or (l.at,'legacy:'||l.id)<(p_before_at,p_before_id)) order by l.at desc,l.id desc limit 51)
 ), limited as (select * from candidates order by at desc,sort_id desc limit 51)
 select coalesce(jsonb_agg(entry order by at desc,sort_id desc),'[]'::jsonb) into page_rows from limited;
 has_more:=jsonb_array_length(page_rows)>50;
 if has_more then page_rows:=page_rows-50;end if;
 tail:=page_rows->(jsonb_array_length(page_rows)-1);
 return jsonb_build_object('rows',page_rows,'hasMore',has_more,'nextCursor',case when has_more then jsonb_build_object('at',tail->'at','id',tail->'id') else null end,
  'periodStart',first_day,'periodEnd',last_day,
  'availableStart',(available_start at time zone 'America/Sao_Paulo')::date,'availableEnd',(available_end at time zone 'America/Sao_Paulo')::date,
  'availableDates',(select coalesce(jsonb_agg(d::date order by d),'[]'::jsonb)
    from generate_series(first_day::timestamp,last_day::timestamp,interval '1 day') d
    where exists(select 1 from public.secap_audit_events e where e.at>=(d at time zone 'America/Sao_Paulo') and e.at<((d+interval '1 day') at time zone 'America/Sao_Paulo'))
       or exists(select 1 from public.secap_audit_legacy l where l.at>=(d at time zone 'America/Sao_Paulo') and l.at<((d+interval '1 day') at time zone 'America/Sao_Paulo'))));
end $function$;

REVOKE ALL ON FUNCTION "public"."secap_audit_page"(text, date, date, timestamp WITH time zone, text, date) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_project_access_list()
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
 if not public.is_admin() then raise exception 'Acesso restrito.' using errcode='42501';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('request_id',r.id,'project_scope',p.project_scope,'project_ids',p.project_ids)) from public.profiles p join public.account_requests r on lower(r.email)=lower(p.email)), '[]');
end$function$;

REVOKE ALL ON FUNCTION "public"."secap_project_access_list"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_read_state()
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare body_value jsonb; personal jsonb; member_email text;
begin
 if not public.is_member() then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 select body into body_value from public.app_state where id=1;
 if body_value is null then return body_value;end if;
 if public.is_admin() then return jsonb_set(body_value,'{logs}','[]'::jsonb);end if;
 select body into personal from public.secap_member_state where owner=auth.uid();
 select lower(email) into member_email from public.profiles where id=auth.uid();
 return jsonb_build_object(
   'projects',coalesce((select jsonb_agg(p) from jsonb_array_elements(body_value->'projects') p where secap_private.project_allowed(p->>'id')),'[]'),
   'users','[]'::jsonb,
   'notes',coalesce(personal->'notes','[]'::jsonb),
   'terms','[]'::jsonb,
   'logs','[]'::jsonb,
   -- O usuário recebe apenas as próprias regras, nunca as permissões dos demais.
   'fieldPermissions',jsonb_build_object(member_email,coalesce(body_value->'fieldPermissions'->member_email,'{}'::jsonb))
 );
end$function$;

REVOKE ALL ON FUNCTION "public"."secap_read_state"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_recover_audit (
  event_id  uuid,
  agreement boolean
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare e public.secap_audit_events%rowtype; r public.obras%rowtype; flat jsonb; patch jsonb; standard boolean; restored public.obras%rowtype;
begin
 if auth.uid() is null or not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito aos administradores.' using errcode='42501';end if;
 if agreement is distinct from true then raise exception 'Confirme: Concordo em voltar.';end if;
 select * into e from public.secap_audit_events where id=event_id for update;
 if not found then raise exception 'Registro de auditoria não encontrado.';end if;
 if exists(select 1 from public.secap_audit_events where recovered_from=event_id) then raise exception 'Esta alteração já foi recuperada.';end if;
 select * into r from public.obras where id=e.record_id and project_id=e.project_id for update;
 if not found then raise exception 'A obra não existe neste projeto. Não é possível recuperar automaticamente.';end if;
 flat := r.dados || (to_jsonb(r)-'dados');
 if (flat->e.field_id) is distinct from e.after_value or (flat ? e.field_id) is distinct from e.after_present then
  raise exception 'O campo mudou depois desta alteração. Atualize a auditoria; a recuperação foi cancelada para não sobrescrever informações mais recentes.' using errcode='40001';
 end if;
 if e.field_id=any(array['id','project_id','created_at','updated_at']) then raise exception 'Campo protegido.';end if;
 standard := (to_jsonb(r)-'dados') ? e.field_id;
 if standard then
  patch := jsonb_build_object(e.field_id,e.before_value);
 else
  patch := jsonb_build_object('dados',case when e.before_present then jsonb_set(r.dados,array[e.field_id],coalesce(e.before_value,'null'::jsonb),true) else r.dados-e.field_id end);
 end if;
 restored := jsonb_populate_record(r,patch);
 perform set_config('secap.recovery_event',event_id::text,true);
 update public.obras set nome=restored.nome,status=restored.status,valor=restored.valor,executado=restored.executado,prazo=restored.prazo,
 responsavel=restored.responsavel,progresso=restored.progresso,proxima=restored.proxima,orgao=restored.orgao,dados=restored.dados,
 nome_planilha=restored.nome_planilha,planilha_id=restored.planilha_id,updated_at=clock_timestamp() where id=r.id returning * into restored;
 perform set_config('secap.recovery_event','',true);
 return jsonb_build_object('ok',true,'obra',to_jsonb(restored),'recovered_event',event_id);
end $function$;

REVOKE ALL ON FUNCTION "public"."secap_recover_audit"(uuid, boolean) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_save_project_state (
  projects          jsonb,
  expected_projects jsonb,
  personal_state    jsonb DEFAULT '{}'::jsonb
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare saved jsonb; current_visible jsonb; next_projects jsonb; item jsonb;
begin
 if not public.is_member() or public.is_admin() then raise exception 'Operação inválida.' using errcode='42501';end if;
 if jsonb_typeof(projects)<>'array' or jsonb_typeof(expected_projects)<>'array' then raise exception 'Projetos inválidos.';end if;
 select body into saved from public.app_state where id=1 for update;
 select coalesce(jsonb_agg(p),'[]') into current_visible from jsonb_array_elements(saved->'projects') p where secap_private.project_allowed(p->>'id');
 if current_visible is distinct from expected_projects then raise exception 'Os projetos ou suas permissões mudaram. Recarregue antes de salvar.' using errcode='40001';end if;
 if (select coalesce(jsonb_agg(p->>'id' order by p->>'id'),'[]') from jsonb_array_elements(projects) p) is distinct from (select coalesce(jsonb_agg(p->>'id' order by p->>'id'),'[]') from jsonb_array_elements(current_visible) p) then raise exception 'Somente administradores podem criar ou excluir pastas de projeto.' using errcode='42501';end if;
 for item in select value from jsonb_array_elements(projects) loop
  if (item - 'records') is distinct from (select p - 'records' from jsonb_array_elements(current_visible) p where p->>'id'=item->>'id') and not secap_private.project_allowed(item->>'id',true) then raise exception 'Você não pode editar este projeto.' using errcode='42501';end if;
 end loop;
 select jsonb_agg(coalesce((select n - 'records' || '{"records":[]}'::jsonb from jsonb_array_elements(projects) n where n->>'id'=p->>'id'),p)) into next_projects from jsonb_array_elements(saved->'projects') p;
 update public.app_state set body=jsonb_set(saved,'{projects}',coalesce(next_projects,'[]')),updated_at=now() where id=1;
 if jsonb_typeof(coalesce(personal_state->'notes','[]'))<>'array' or jsonb_typeof(coalesce(personal_state->'logs','[]'))<>'array' then raise exception 'Dados pessoais inválidos.';end if;
 insert into public.secap_member_state(owner,body) values(auth.uid(),jsonb_build_object('notes',coalesce(personal_state->'notes','[]'),'logs',coalesce(personal_state->'logs','[]'))) on conflict(owner) do update set body=jsonb_set(excluded.body,'{logs}',
   (select coalesce(jsonb_agg(entry),'[]'::jsonb) from
     (select distinct value as entry from jsonb_array_elements(
       coalesce(public.secap_member_state.body->'logs','[]'::jsonb) || coalesce(excluded.body->'logs','[]'::jsonb)
     )) preserved_logs));
 return true;
end$function$;

REVOKE ALL ON FUNCTION "public"."secap_save_project_state"(jsonb, jsonb, jsonb) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_set_project_access (
  request_id  bigint,
  scope       text,
  project_ids text[]
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare target_email text; valid_ids text[];
begin
 if not public.is_admin() then raise exception 'Acesso restrito.' using errcode='42501';end if;
 if scope not in ('all','selected') or scope is null or project_ids is null then raise exception 'Seleção inválida.';end if;
 select coalesce(array_agg(p->>'id'),'{}') into valid_ids from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p where s.id=1;
 if not secap_set_project_access.project_ids <@ valid_ids then raise exception 'Um dos projetos não existe mais. Atualize a lista.';end if;
 select r.email into target_email from public.account_requests r where r.id=request_id and r.status='Aprovada';
 if not found then return false;end if;
 update public.profiles p set project_scope=scope,project_ids=case when scope='all' then '{}'::text[] else (select coalesce(array_agg(distinct x),'{}') from unnest(secap_set_project_access.project_ids) x) end where lower(p.email)=lower(target_email) and p.role='usuario';
 return found;
end$function$;

REVOKE ALL ON FUNCTION "public"."secap_set_project_access"(bigint, text, text[]) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_set_user_role (
  request_id bigint,
  new_role   text
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare target_email text; target_id uuid; target_role text; principal_id uuid;
begin
 if not public.is_admin() then raise exception 'Acesso restrito.' using errcode='42501';end if;
 if new_role is null or new_role not in ('administrador','usuario') then raise exception 'Perfil inválido.' using errcode='22023';end if;
 select r.email into target_email from public.account_requests r where r.id=request_id and r.status='Aprovada';
 if not found then return false;end if;
 select p.id,p.role into target_id,target_role from public.profiles p where lower(p.email)=lower(target_email) for update;
 if not found or target_role not in ('administrador','usuario') then return false;end if;
 if target_id=auth.uid() then raise exception 'Você não pode alterar o seu próprio perfil.' using errcode='42501';end if;
 if target_role=new_role then return true;end if;
 if new_role='usuario' then
  select p.id into principal_id from public.profiles p where p.role='administrador' order by p.created_at,p.id limit 1;
  if target_id=principal_id then raise exception 'O administrador principal não pode ser rebaixado.' using errcode='42501';end if;
  update public.profiles set role='usuario',obras_access='visualizar',project_scope='selected',project_ids='{}' where id=target_id;
 else
  update public.profiles set role='administrador' where id=target_id;
 end if;
 return true;
end$function$;

REVOKE ALL ON FUNCTION "public"."secap_set_user_role"(bigint, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.secap_update_my_name (
  new_name text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare clean_name text; changed_name text;
begin
 if auth.uid() is null or not coalesce(public.is_member(),false) then raise exception 'Acesso não aprovado.' using errcode='42501';end if;
 clean_name:=btrim(new_name);
 if clean_name is null or clean_name='' or char_length(clean_name)>120 then raise exception 'Informe um nome válido com até 120 caracteres.';end if;
 update public.profiles set name=clean_name where id=auth.uid() returning name into changed_name;
 if not found then raise exception 'Perfil da conta não encontrado.';end if;
 return jsonb_build_object('name',changed_name);
end $function$;

REVOKE ALL ON FUNCTION "public"."secap_update_my_name"(text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.sync_planilha_after_obra_delete()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  restante integer;
begin
  if old.planilha_id is null then
    return old;
  end if;

  select count(*) into restante from public.obras where planilha_id = old.planilha_id;

  if restante = 0 then
    delete from public.planilhas_importadas where id = old.planilha_id;
  else
    update public.planilhas_importadas set total_obras = restante where id = old.planilha_id;
  end if;

  return old;
end;
$function$;

CREATE OR REPLACE FUNCTION secap_private.audit_actor_name (
  actor_id    uuid,
  actor_email text DEFAULT NULL::text
)
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select coalesce(
  (select nullif(btrim(p.name),'') from public.profiles p where (p.id=actor_id or (actor_id is null and lower(p.email)=lower(actor_email))) and position('@' in p.name)=0),
  (select nullif(btrim(r.name),'') from public.account_requests r where lower(r.email)=lower(coalesce((select p.email from public.profiles p where p.id=actor_id),case when position('@' in actor_email)>0 then actor_email end)) and position('@' in r.name)=0 order by r.created_at desc limit 1),
  (select coalesce(nullif(btrim(u.raw_user_meta_data->>'name'),''),nullif(btrim(u.raw_user_meta_data->>'full_name'),'')) from auth.users u where u.id=actor_id),
  'Nome não informado');
$function$;

CREATE OR REPLACE FUNCTION secap_private.audit_entry_name (
  entry jsonb
)
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare actor_id uuid; stored_name text; actor_email text; resolved text;
begin
 stored_name:=btrim(coalesce(entry->>'who',''));
 if stored_name<>'' and stored_name not in ('Nome não informado','Usuário não informado') and position('@' in stored_name)=0 then return stored_name;end if;
 if coalesce(entry->>'user','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then actor_id:=(entry->>'user')::uuid;end if;
 actor_email:=case when position('@' in stored_name)>0 then stored_name when position('@' in coalesce(entry->>'email',''))>0 then entry->>'email' end;
 resolved:=secap_private.audit_actor_name(actor_id,actor_email);
 return resolved;
end $function$;

CREATE OR REPLACE FUNCTION secap_private.capture_legacy_audit()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
 if tg_table_name='app_state' then
  if tg_op='UPDATE' then perform secap_private.index_legacy_audit(old.body->'logs');end if;
  perform secap_private.index_legacy_audit(new.body->'logs');
 else
  if tg_op='UPDATE' then perform secap_private.index_legacy_audit(old.body->'logs',old.owner);end if;
  perform secap_private.index_legacy_audit(new.body->'logs',new.owner);
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION secap_private.capture_obra_audit()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare old_flat jsonb; new_flat jsonb; k text; pname text; fname text; actor_name text;
begin
 old_flat := old.dados || (to_jsonb(old) - 'dados');
 new_flat := new.dados || (to_jsonb(new) - 'dados');
 select secap_private.audit_actor_name(auth.uid()) into actor_name;
 select p->>'name' into pname from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p where s.id=1 and p->>'id'=new.project_id;
 for k in select jsonb_object_keys(old_flat || new_flat) loop
  if k = any(array['id','project_id','created_at','updated_at']) then continue; end if;
  if (old_flat->k) is not distinct from (new_flat->k) and (old_flat ? k) = (new_flat ? k) then continue;end if;
  select f->>'name' into fname from public.app_state s cross join lateral jsonb_array_elements(s.body->'projects') p
   cross join lateral jsonb_array_elements(coalesce(p->'fields','[]'::jsonb)) f where s.id=1 and p->>'id'=new.project_id and f->>'id'=k limit 1;
  insert into public.secap_audit_events(actor,who,project_id,project_name,record_id,record_name,field_id,field_name,before_value,after_value,before_present,after_present,action,recovered_from)
   values(auth.uid(),coalesce(actor_name,'Sistema'),new.project_id,coalesce(pname,new.project_id),new.id,new.nome,k,coalesce(fname,k),old_flat->k,new_flat->k,old_flat ? k,new_flat ? k,
    case when nullif(current_setting('secap.recovery_event',true),'') is null then 'Alterou campo' else 'Recuperou informação anterior' end,
    nullif(current_setting('secap.recovery_event',true),'')::uuid);
 end loop;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION secap_private.index_legacy_audit (
  entries  jsonb,
  owner_id uuid  DEFAULT NULL::uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare e jsonb; stamp timestamptz; actor_name text;
begin
 if jsonb_typeof(entries) is distinct from 'array' then return;end if;
 if owner_id is not null then select secap_private.audit_actor_name(owner_id) into actor_name;end if;
 for e in select value from jsonb_array_elements(entries) loop
  begin stamp := (e->>'at')::timestamptz;exception when others then stamp:=null;end;
  if stamp is null then continue;end if;
  if owner_id is not null then e:=e || jsonb_build_object('user',owner_id,'who',coalesce(actor_name,e->>'who','Usuário não informado'));end if;
  insert into public.secap_audit_legacy(id,at,entry)
   values(coalesce(nullif(e->>'id',''),md5(e::text)),stamp,e) on conflict(id) do nothing;
 end loop;
end $function$;

CREATE OR REPLACE FUNCTION secap_private.project_allowed (
  pid     text,
  editing boolean DEFAULT false
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and (p.role='administrador' or (p.role='usuario' and (p.project_scope='all' or pid=any(p.project_ids)) and (not editing or p.obras_access='editar'))));
$function$;

ALTER TABLE "public"."obra_section_configs"
  ADD CONSTRAINT "obra_section_configs_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id);

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_project_scope_check" CHECK ((project_scope = ANY (ARRAY['all'::text, 'selected'::text])));

ALTER TABLE "public"."secap_audit_events"
  ADD CONSTRAINT "secap_audit_events_recovered_from_fkey" FOREIGN KEY (recovered_from) REFERENCES public.secap_audit_events(id);

ALTER TABLE "public"."secap_member_state"
  ADD CONSTRAINT "secap_member_state_owner_fkey" FOREIGN KEY (OWNER) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_custom_dashboards"
  ADD CONSTRAINT "user_custom_dashboards_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX secap_audit_at_idx ON public.secap_audit_events USING btree (at DESC);

CREATE INDEX secap_audit_events_page_idx ON public.secap_audit_events USING btree (at DESC, id DESC);

CREATE INDEX secap_audit_legacy_at_idx ON public.secap_audit_legacy USING btree (at DESC, id DESC);

CREATE TRIGGER secap_index_audit_state
  AFTER INSERT OR UPDATE OF body ON public.app_state
  FOR EACH ROW
  EXECUTE FUNCTION secap_private.capture_legacy_audit();

CREATE TRIGGER obras_delete_permissions_guard
  BEFORE DELETE ON public.obras
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_obras_delete_permissions();

CREATE TRIGGER obras_field_permissions_guard
  BEFORE INSERT OR UPDATE ON public.obras
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_obras_field_permissions();

CREATE TRIGGER secap_capture_audit
  AFTER UPDATE ON public.obras
  FOR EACH ROW
  EXECUTE FUNCTION secap_private.capture_obra_audit();

CREATE TRIGGER secap_index_audit_member
  AFTER INSERT OR UPDATE OF body ON public.secap_member_state
  FOR EACH ROW
  EXECUTE FUNCTION secap_private.capture_legacy_audit();

CREATE POLICY "scoped_state_admin" ON "public"."app_state"
  FOR ALL
  TO "authenticated"
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "project_delete" ON "public"."obras"
  FOR DELETE
  TO "authenticated"
  USING (secap_private.project_allowed(project_id, true));

CREATE POLICY "project_insert" ON "public"."obras"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (secap_private.project_allowed(project_id, true));

CREATE POLICY "project_read" ON "public"."obras"
  FOR SELECT
  TO "authenticated"
  USING (secap_private.project_allowed(project_id));

CREATE POLICY "project_update" ON "public"."obras"
  FOR UPDATE
  TO "authenticated"
  USING (secap_private.project_allowed(project_id, true))
  WITH CHECK (secap_private.project_allowed(project_id, true));

CREATE POLICY "project_delete" ON "public"."planilhas_importadas"
  FOR DELETE
  TO "authenticated"
  USING (secap_private.project_allowed(project_id, true));

CREATE POLICY "project_insert" ON "public"."planilhas_importadas"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (secap_private.project_allowed(project_id, true));

CREATE POLICY "project_read" ON "public"."planilhas_importadas"
  FOR SELECT
  TO "authenticated"
  USING (secap_private.project_allowed(project_id));

CREATE POLICY "project_update" ON "public"."planilhas_importadas"
  FOR UPDATE
  TO "authenticated"
  USING (secap_private.project_allowed(project_id, true))
  WITH CHECK (secap_private.project_allowed(project_id, true));

CREATE POLICY "audit_admin_read" ON "public"."secap_audit_events"
  FOR SELECT
  TO "authenticated"
  USING (public.is_admin());

CREATE POLICY "audit_legacy_admin_read" ON "public"."secap_audit_legacy"
  FOR SELECT
  TO "authenticated"
  USING (public.is_admin());

CREATE POLICY "Utilizadores gerem os seus próprios painéis BI" ON "public"."user_custom_dashboards"
  FOR ALL
  TO "authenticated"
  USING ((auth.uid() = user_id))
  WITH CHECK ((auth.uid() = user_id));

REVOKE ALL ON FUNCTION "public"."guard_obras_delete_permissions"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."guard_obras_delete_permissions"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."guard_obras_delete_permissions"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."guard_obras_field_permissions"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."guard_obras_field_permissions"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."guard_obras_field_permissions"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_audit_logs"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_audit_logs"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_audit_logs"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_audit_logs"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_audit_page"(text, date, date, timestamp WITH time zone, text, date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_audit_page"(text, date, date, timestamp WITH time zone, text, date) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_audit_page"(text, date, date, timestamp WITH time zone, text, date) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_audit_page"(text, date, date, timestamp WITH time zone, text, date) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_project_access_list"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_project_access_list"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_project_access_list"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_project_access_list"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_read_state"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_read_state"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_read_state"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_read_state"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_recover_audit"(uuid, boolean) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_recover_audit"(uuid, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_recover_audit"(uuid, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_recover_audit"(uuid, boolean) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_save_project_state"(jsonb, jsonb, jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_save_project_state"(jsonb, jsonb, jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_save_project_state"(jsonb, jsonb, jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_save_project_state"(jsonb, jsonb, jsonb) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_set_project_access"(bigint, text, text[]) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_set_project_access"(bigint, text, text[]) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_set_project_access"(bigint, text, text[]) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_set_project_access"(bigint, text, text[]) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_set_user_role"(bigint, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_set_user_role"(bigint, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_set_user_role"(bigint, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_set_user_role"(bigint, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."secap_update_my_name"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."secap_update_my_name"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_update_my_name"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."secap_update_my_name"(text) TO "service_role";

REVOKE ALL ON FUNCTION "secap_private"."audit_actor_name"(uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION "secap_private"."audit_entry_name"(jsonb) FROM PUBLIC;

REVOKE ALL ON FUNCTION "secap_private"."capture_legacy_audit"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "secap_private"."capture_obra_audit"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "secap_private"."index_legacy_audit"(jsonb, uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION "secap_private"."project_allowed"(text, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "secap_private"."project_allowed"(text, boolean) TO "authenticated";

GRANT USAGE ON SCHEMA "secap_private" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."obra_section_configs" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."obra_section_configs" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."obra_section_configs" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."obra_section_configs" TO "service_role";

REVOKE ALL ON TABLE "public"."secap_audit_events" FROM "authenticated";

GRANT SELECT ON TABLE "public"."secap_audit_events" TO "authenticated";

REVOKE ALL ON TABLE "public"."secap_audit_events" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."secap_audit_events" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."secap_audit_events" TO "service_role";

REVOKE ALL ON TABLE "public"."secap_audit_legacy" FROM "authenticated";

GRANT SELECT ON TABLE "public"."secap_audit_legacy" TO "authenticated";

REVOKE ALL ON TABLE "public"."secap_audit_legacy" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."secap_audit_legacy" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."secap_audit_legacy" TO "service_role";

REVOKE ALL ON TABLE "public"."secap_member_state" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."secap_member_state" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."secap_member_state" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_custom_dashboards" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."user_custom_dashboards" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_custom_dashboards" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_custom_dashboards" TO "service_role";
