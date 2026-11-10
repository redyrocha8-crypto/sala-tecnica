-- =====================================================================
-- Sala Técnica · EIBI Serra da Ibiapaba
-- 01_schema.sql — tabelas, regras de acesso (RLS) e funções de login
-- Rode este arquivo inteiro no Supabase: SQL Editor → New query → Run
-- =====================================================================

-- ---------- Tabelas ----------
create table if not exists public.config (
  chave          text primary key,
  valor          jsonb not null default '{}'::jsonb,
  atualizado_em  timestamptz not null default now()
);

create table if not exists public.acessos (
  email          text primary key check (email = lower(email)),
  nome           text not null unique,
  setor          text,
  papel          text not null default 'membro' check (papel in ('admin','membro','leitura')),
  ativo          boolean not null default true,
  criado_em      timestamptz default now(),
  criado_por     text,
  atualizado_em  timestamptz,
  atualizado_por text
);

create table if not exists public.demandas (
  id             text primary key,
  codigo         text not null,
  titulo         text not null,
  descricao      text not null default '',
  responsaveis   text[] not null default '{}',
  setor          text,
  status         text not null default 'afazer'
                 check (status in ('afazer','andamento','revisao','bloqueada','rotina','concluida')),
  prioridade     text not null default ''
                 check (prioridade in ('','urgente','alta','normal','baixa')),
  inicio         date,
  prazo          date,
  concluida_em   date,
  tags           text[] not null default '{}',
  checklist      jsonb not null default '[]'::jsonb,
  atualizacoes   jsonb not null default '[]'::jsonb,
  criada_em      timestamptz not null default now(),
  criado_por     text,
  atualizada_em  timestamptz,
  atualizada_por text
);
create index if not exists demandas_setor_idx  on public.demandas (setor);
create index if not exists demandas_status_idx on public.demandas (status);

-- ---------- Funções auxiliares (quem está logado) ----------
create or replace function public.meu_email() returns text
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

create or replace function public.eh_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.acessos where email = public.meu_email() and ativo)
$$;

create or replace function public.eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.acessos where email = public.meu_email() and ativo and papel = 'admin')
$$;

create or replace function public.pode_criar() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.acessos where email = public.meu_email() and ativo and papel in ('admin','membro'))
$$;

-- Regra central: admin edita tudo; membro edita demandas do próprio setor,
-- as que criou e as em que é responsável; leitura não edita nada.
create or replace function public.pode_editar(d_setor text, d_criado_por text, d_resp text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.acessos a
    where a.email = public.meu_email() and a.ativo
      and ( a.papel = 'admin'
            or ( a.papel = 'membro'
                 and ( a.setor = d_setor
                       or lower(coalesce(d_criado_por,'')) = a.email
                       or a.nome = any(coalesce(d_resp, '{}')) ) ) )
  )
$$;

-- ---------- Regras de acesso (Row Level Security) ----------
alter table public.config   enable row level security;
alter table public.acessos  enable row level security;
alter table public.demandas enable row level security;

drop policy if exists config_ler     on public.config;
drop policy if exists config_admin   on public.config;
create policy config_ler   on public.config for select to authenticated using (public.eh_membro());
create policy config_admin on public.config for all    to authenticated using (public.eh_admin()) with check (public.eh_admin());

drop policy if exists acessos_ler   on public.acessos;
drop policy if exists acessos_admin on public.acessos;
create policy acessos_ler   on public.acessos for select to authenticated using (public.eh_membro());
create policy acessos_admin on public.acessos for all    to authenticated using (public.eh_admin()) with check (public.eh_admin());

drop policy if exists demandas_ler     on public.demandas;
drop policy if exists demandas_criar   on public.demandas;
drop policy if exists demandas_editar  on public.demandas;
drop policy if exists demandas_excluir on public.demandas;
create policy demandas_ler    on public.demandas for select to authenticated using (public.eh_membro());
create policy demandas_criar  on public.demandas for insert to authenticated
  with check (public.pode_criar() and lower(coalesce(criado_por,'')) = public.meu_email());
create policy demandas_editar on public.demandas for update to authenticated
  using (public.pode_editar(setor, criado_por, responsaveis))
  with check (public.pode_editar(setor, criado_por, responsaveis));
create policy demandas_excluir on public.demandas for delete to authenticated
  using (public.pode_editar(setor, criado_por, responsaveis));

-- ---------- Login: só e-mails cadastrados podem criar conta ----------
create or replace function public.bloquear_cadastro_nao_autorizado() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.acessos where email = lower(new.email) and ativo) then
    raise exception 'E-mail sem acesso a Sala Tecnica';
  end if;
  return new;
end $$;

drop trigger if exists antes_cadastro_sala_tecnica on auth.users;
create trigger antes_cadastro_sala_tecnica
  before insert on auth.users
  for each row execute function public.bloquear_cadastro_nao_autorizado();

-- Usado na tela de login, antes de entrar: o e-mail tem acesso? já criou senha?
create or replace function public.verificar_email(p_email text) returns jsonb
language sql stable security definer set search_path = public, auth as $$
  select jsonb_build_object(
    'status', case when a.email is null then 'nao' when not a.ativo then 'inativo' else 'ok' end,
    'tem_conta', case when a.ativo then exists (select 1 from auth.users u where lower(u.email) = a.email) else false end)
  from (select lower(trim(p_email)) as e) x
  left join public.acessos a on a.email = x.e
$$;
grant execute on function public.verificar_email(text) to anon, authenticated;

-- Aba Administração: quem já criou senha e último acesso
create or replace function public.status_acessos()
returns table (email text, tem_conta boolean, ultimo_acesso timestamptz)
language sql stable security definer set search_path = public, auth as $$
  select a.email, (u.id is not null), u.last_sign_in_at
  from public.acessos a
  left join auth.users u on lower(u.email) = a.email
  where public.eh_admin()
$$;
grant execute on function public.status_acessos() to authenticated;

-- Aba Administração: redefinir senha (apaga a conta; a pessoa cria nova senha no próximo acesso)
create or replace function public.admin_redefinir_senha(p_email text) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.eh_admin() then raise exception 'Somente administradores'; end if;
  if lower(p_email) = public.meu_email() then raise exception 'Use outro administrador para redefinir a sua senha'; end if;
  delete from auth.users where lower(email) = lower(p_email);
end $$;
revoke execute on function public.admin_redefinir_senha(text) from anon;
grant execute on function public.admin_redefinir_senha(text) to authenticated;

-- ---------- Tempo real (atualiza a tela de todos quando alguém salva) ----------
do $$ begin
  begin alter publication supabase_realtime add table public.demandas; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.acessos;  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.config;   exception when duplicate_object then null; end;
end $$;
