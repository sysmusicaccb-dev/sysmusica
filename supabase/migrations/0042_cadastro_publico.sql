-- 0042 — Parte 9: Cadastro Musical PÚBLICO (link único, sem login) e fila "Cadastros pendentes"
--
-- O QUE ESTA MIGRAÇÃO FAZ
--   A) Tabelas novas (cadastros_pendentes, cadastro_publico_uploads, cadastro_publico_limites), todas com RLS ligado e
--      NENHUM acesso direto para anon/authenticated: tudo passa por funções.
--   B) Bucket privado "cadastro-publico" SEM políticas: só o servidor (chave de serviço) grava e lê. Os arquivos ficam ali
--      até o cadastro ser aprovado (aí vão para fotos-membros / documentos-membros) ou apagados pela limpeza diária.
--   C) Funções:
--        PÚBLICA (anon):  opcoes_cadastro_publico()            -> cargos, instrumentos, famílias e Casas de Oração
--        SERVIDOR:        iniciar_envio_publico, registrar_cadastro_publico, limpeza_cadastro_publico,
--                         marcar_cadastros_limpos              (somente chave de serviço; o navegador NUNCA as chama)
--        PAINEL:          listar/obter/contar_cadastros_pendentes, aprovar_cadastro_pendente, rejeitar_cadastro_pendente
--   D) Permissões: cadastros.visualizar e cadastros.aprovar (só o Administrador recebe; os demais grupos são
--      liberados em Grupos e permissões). A abrangência (casa_oracao_na_abrangencia) vale para tudo.
--   E) membros_antes_de_gravar passa a aceitar o CPF quando quem grava é a função de aprovação (o aprovador pode
--      não ter a permissão membros.cpf; ele já tem cadastros.aprovar).
--   F) Backup: backup_aplicar passa a conhecer cadastros_pendentes e membros_cadastro.
--
-- LIMITES DE SEGURANÇA (ajuste aqui se precisar): 30 envios por hora por IP, 600 por hora no total,
-- 3 envios por dia por CPF. Pendente sem análise vence em 60 dias; recusado tem os arquivos apagados em 30 dias.
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.membros') is null or to_regclass('public.membros_cadastro') is null
     or to_regclass('public.hinos') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.registrar_auditoria(text, text, uuid, jsonb)') is null
     or to_regprocedure('public.casa_oracao_na_abrangencia(uuid)') is null
     or to_regprocedure('public.validar_foto_membro(uuid, text)') is null
     or to_regprocedure('public.cpf_valido(text)') is null
     or to_regprocedure('public.limpar_espacos(text)') is null
     or to_regprocedure('public.instrumento_e_orgao(text)') is null
     or to_regprocedure('public.backup_aplicar(uuid, jsonb, jsonb)') is null then
    raise exception 'Aplique primeiro as migrações até a 0041. Nada foi alterado.';
  end if;
  if to_regclass('public.cadastros_pendentes') is not null then
    raise exception 'A migração 0042 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Apoio
-- ---------------------------------------------------------------------------
-- Cargos que têm Cadastro Musical (mesma lista de CARGOS_DO_CADASTRO em src/modules/membros/cadastroMusical.ts)
create or replace function public.cargo_aceita_cadastro_publico(p_nome text)
returns boolean language sql immutable set search_path to 'public'
as $$ select public.normalizar_texto(p_nome) ~ '^(encarregado regional|encarregado local|examinadora|instrutor|musico|organista)' $$;

-- Texto -> data, ou nulo se não for uma data válida (evita erro técnico aparecer para o público)
create or replace function public.data_ou_nula(p_texto text)
returns date language plpgsql immutable set search_path to 'public'
as $$
begin
  if p_texto is null or p_texto !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return null; end if;
  return p_texto::date;
exception when others then
  return null;
end;
$$;

-- CPF com a parte do meio escondida (para listas)
create or replace function public.cpf_escondido(p_cpf text)
returns text language sql immutable set search_path to 'public'
as $$ select case when p_cpf is null then null else '***.' || substr(p_cpf, 4, 3) || '.***-' || right(p_cpf, 2) end $$;

-- ---------------------------------------------------------------------------
-- 2. Tabelas
-- ---------------------------------------------------------------------------
-- Pedidos de cadastro feitos pela página pública. NADA aqui vira membro sem uma pessoa aprovar.
create table public.cadastros_pendentes (
  -- O id é o mesmo da pasta dos arquivos no bucket cadastro-publico (<id>/foto.jpg, frente.jpg, verso.jpg)
  id                    uuid primary key,
  tipo                  text not null check (tipo in ('NOVO', 'ATUALIZACAO')),
  status                text not null default 'PENDENTE'
                        check (status in ('PENDENTE', 'APROVADO', 'REJEITADO', 'EXPIRADO', 'SUBSTITUIDO')),
  -- ATUALIZACAO: o membro que já existe. NOVO aprovado: o membro criado.
  membro_id             uuid references public.membros (id) on delete set null,
  casa_oracao_id        uuid not null references public.casas_oracao (id),
  -- Dados pessoais: são apagados (viram nulo) quando os arquivos são apagados de um pedido não aprovado
  nome                  text,
  cpf                   text check (cpf is null or public.cpf_valido(cpf)),
  data_nascimento       date,
  cidade                text,
  bairro                text,
  cargo_id              uuid references public.cargos (id),
  instrumento_id        uuid references public.instrumentos (id) on delete set null,
  categoria             text check (categoria is null or categoria in ('OFICIALIZADO', 'CULTO_OFICIAL', 'RJM')),
  dados                 jsonb not null default '{}'::jsonb,   -- campos de membros_cadastro (sem os caminhos dos arquivos)
  -- Menores de 18 anos
  responsavel_nome      text,
  responsavel_telefone  text,
  aceite_responsavel    boolean not null default false,
  -- Consentimento (LGPD): versão do aviso aceito e quando
  aviso_versao          text not null,
  aceite_em             timestamptz not null default now(),
  ip_hash               text,
  -- O CPF já existe no sistema, mas com outra data de nascimento: o aprovador precisa conferir com cuidado
  cpf_conflito          boolean not null default false,
  criado_em             timestamptz not null default now(),
  expira_em             timestamptz not null default (now() + interval '60 days'),
  decidido_em           timestamptz,
  decidido_por          uuid,
  motivo_rejeicao       text check (motivo_rejeicao is null or char_length(motivo_rejeicao) <= 300),
  arquivos_apagados_em  timestamptz
);
create index idx_cadastros_pendentes_status on public.cadastros_pendentes (status, criado_em);
create index idx_cadastros_pendentes_cpf on public.cadastros_pendentes (cpf) where cpf is not null;
create index idx_cadastros_pendentes_casa on public.cadastros_pendentes (casa_oracao_id);

-- Envios iniciados (o id vira o id do pedido). Serve para só aceitar dados de quem enviou arquivos antes.
create table public.cadastro_publico_uploads (
  id         uuid primary key default gen_random_uuid(),
  ip_hash    text,
  criado_em  timestamptz not null default now(),
  usado      boolean not null default false
);
create index idx_cadastro_publico_uploads_criado on public.cadastro_publico_uploads (criado_em);

-- Registro das tentativas (limite por IP, por CPF e geral). A chave é sempre um hash, nunca o IP/CPF puro.
create table public.cadastro_publico_limites (
  id         bigint generated always as identity primary key,
  tipo       text not null check (tipo in ('ip', 'cpf', 'geral')),
  chave      text not null,
  criado_em  timestamptz not null default now()
);
create index idx_cadastro_publico_limites on public.cadastro_publico_limites (tipo, chave, criado_em);

alter table public.cadastros_pendentes enable row level security;
alter table public.cadastro_publico_uploads enable row level security;
alter table public.cadastro_publico_limites enable row level security;
revoke all on public.cadastros_pendentes from public, anon, authenticated;
revoke all on public.cadastro_publico_uploads from public, anon, authenticated;
revoke all on public.cadastro_publico_limites from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Armazenamento PRIVADO do cadastro público (sem políticas: só a chave de serviço do servidor acessa)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cadastro-publico', 'cadastro-publico', false, 3145728, array['image/jpeg'])
on conflict (id) do update
   set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg'];

-- ---------------------------------------------------------------------------
-- 4. Permissões (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe.
-- ---------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('cadastros.visualizar', 'Cadastros pendentes', 'Visualizar', 'Ver os cadastros enviados pelo link público, aguardando análise'),
  ('cadastros.aprovar',    'Cadastros pendentes', 'Aprovar',    'Aprovar ou recusar os cadastros enviados pelo link público')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo in ('cadastros.visualizar', 'cadastros.aprovar')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 5. membros_antes_de_gravar: aceita o CPF quando a gravação vem da função de aprovação
--    (cópia da versão atual; só muda a condição do bloco do CPF)
-- ---------------------------------------------------------------------------
create or replace function public.membros_antes_de_gravar()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_logado boolean := (select auth.uid()) is not null;
  -- Ligado só dentro de aprovar_cadastro_pendente (que já exige a permissão cadastros.aprovar)
  v_aprovando boolean := coalesce(current_setting('sysmusica.aprovando_cadastro', true), '') = 'sim';
begin
  if v_logado and not v_aprovando then
    if tg_op = 'INSERT' then
      if new.cpf is not null and not public.tem_permissao('membros.cpf') then
        raise exception 'Você não tem permissão para informar o CPF.' using errcode = '42501';
      end if;
    elsif new.cpf is distinct from old.cpf and not public.tem_permissao('membros.cpf') then
      raise exception 'Você não tem permissão para alterar o CPF.' using errcode = '42501';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    new.atualizado_em := now();
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Função PÚBLICA: opções do formulário (qualquer pessoa, sem login)
--    Expõe só nomes de cargos, instrumentos, famílias e Casas de Oração (com o caminho na organização).
-- ---------------------------------------------------------------------------
create or replace function public.opcoes_cadastro_publico()
returns jsonb
language sql stable security definer set search_path to 'public'
as $$
  select jsonb_build_object(
    'cargos', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', c.id, 'nome', c.nome, 'permite_instrumento', c.permite_instrumento,
                  'exige_instrumento', c.exige_instrumento, 'exige_cartao', c.exige_cartao,
                  'somente_orgao', c.somente_orgao) order by c.nome), '[]'::jsonb)
                 from public.cargos c where public.cargo_aceita_cadastro_publico(c.nome)),
    'instrumentos', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'nome', i.nome, 'familia_id', i.familia_id)
                  order by i.nome), '[]'::jsonb) from public.instrumentos i),
    'familias', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'nome', f.nome) order by f.nome), '[]'::jsonb)
                 from public.familias f),
    'casas', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', ca.id, 'nome', ca.nome, 'adm', a.nome, 'ra', r.nome, 'rrm', rr.nome, 'setor', s.nome)
                  order by ca.nome), '[]'::jsonb)
                from public.casas_oracao ca
                left join public.setores s on s.id = ca.setor_id
                left join public.adms a on a.id = coalesce(ca.adm_id, s.adm_id)
                left join public.ras r on r.id = a.ra_id
                left join public.rrms rr on rr.id = r.rrm_id
               where ca.ativo)
  )
$$;

-- ---------------------------------------------------------------------------
-- 7. Funções do SERVIDOR (somente chave de serviço)
-- ---------------------------------------------------------------------------
-- Controla o limite de tentativas. Lança P0429 quando passou do limite.
create or replace function public.cadastro_publico_limite(p_tipo text, p_chave text, p_max integer, p_janela interval)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare v_qtd integer;
begin
  select count(*) into v_qtd from public.cadastro_publico_limites
   where tipo = p_tipo and chave = p_chave and criado_em > now() - p_janela;
  if v_qtd >= p_max then
    raise exception 'Muitas tentativas. Aguarde um pouco e tente novamente.' using errcode = 'P0429';
  end if;
  insert into public.cadastro_publico_limites (tipo, chave) values (p_tipo, p_chave);
end;
$$;

-- Passo 1 do envio: confere o limite e cria o id do envio (a pasta dos arquivos).
create or replace function public.iniciar_envio_publico(p_ip_hash text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare v_id uuid;
begin
  perform public.cadastro_publico_limite('geral', 'todos', 600, interval '1 hour');
  if p_ip_hash is not null then
    perform public.cadastro_publico_limite('ip', p_ip_hash, 30, interval '1 hour');
  end if;
  insert into public.cadastro_publico_uploads (ip_hash) values (p_ip_hash) returning id into v_id;
  return v_id;
end;
$$;

-- Passo 2: confere TUDO de novo (a tela é só a resposta rápida) e grava o pedido. Nunca revela se o CPF já existia.
create or replace function public.registrar_cadastro_publico(p_envio uuid, p_dados jsonb, p_ip_hash text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  d              jsonb;
  v_cad          jsonb;
  v_nome         text;
  v_cpf          text;
  v_nasc         date;
  v_casa         uuid;
  v_cargo        record;
  v_cargo_id     uuid;
  v_instr        uuid;
  v_instr_nome   text;
  v_categoria    text;
  v_cidade       text;
  v_bairro       text;
  v_menor        boolean;
  v_resp_nome    text;
  v_resp_tel     text;
  v_ace_resp     boolean;
  v_aviso        text;
  v_membro       uuid;
  v_membro_nasc  date;
  v_tipo         text := 'NOVO';
  v_conflito     boolean := false;
  v_usa_categ    boolean;
  v_batizado     boolean;
  v_dbat         date;
  v_demi         date;
  v_dval         date;
  v_limpo        jsonb;
  v_ec text; v_sx text; v_ddd text; v_tel text; v_wpp text; v_email text; v_cep text; v_end text; v_num text;
  v_comp text; v_uf text; v_cnum text;
begin
  if p_dados is null or jsonb_typeof(p_dados) <> 'object' then
    raise exception 'Não foi possível enviar o cadastro. Atualize a página e tente de novo.';
  end if;
  d := p_dados;

  -- O envio precisa ter sido iniciado há pouco e ainda não usado
  if not exists (select 1 from public.cadastro_publico_uploads u
                  where u.id = p_envio and not u.usado and u.criado_em > now() - interval '2 hours') then
    raise exception 'O envio expirou. Atualize a página e tente de novo.';
  end if;
  -- As três imagens precisam estar no armazenamento
  if (select count(*) from storage.objects o
       where o.bucket_id = 'cadastro-publico'
         and o.name in (p_envio::text || '/foto.jpg', p_envio::text || '/frente.jpg', p_envio::text || '/verso.jpg')) <> 3 then
    raise exception 'As imagens não foram enviadas. Tente novamente.';
  end if;

  -- Armadilha contra robôs
  if nullif(btrim(d ->> 'site'), '') is not null then
    raise exception 'Não foi possível enviar o cadastro. Atualize a página e tente de novo.';
  end if;
  if d -> 'aceite_privacidade' is distinct from 'true'::jsonb then
    raise exception 'Para enviar, é preciso concordar com o aviso de privacidade.';
  end if;
  v_aviso := nullif(btrim(d ->> 'aviso_versao'), '');
  if v_aviso is null or char_length(v_aviso) > 40 then
    raise exception 'Atualize a página e tente de novo.';
  end if;

  -- Identificação
  v_nome := public.limpar_espacos(d ->> 'nome');
  if v_nome is null or char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Informe o nome completo (nome e sobrenome).';
  end if;
  v_cpf := nullif(btrim(d ->> 'cpf'), '');
  if v_cpf is null or not public.cpf_valido(v_cpf) then
    raise exception 'CPF inválido. Confira os números digitados.';
  end if;
  v_nasc := public.data_ou_nula(d ->> 'data_nascimento');
  if v_nasc is null or v_nasc > current_date or v_nasc < date '1900-01-01' then
    raise exception 'Data de nascimento inválida.';
  end if;
  v_cidade := public.limpar_espacos(d ->> 'cidade');
  v_bairro := public.limpar_espacos(d ->> 'bairro');
  if v_cidade is null or v_bairro is null or char_length(v_cidade) > 80 or char_length(v_bairro) > 80 then
    raise exception 'Informe a cidade e o bairro.';
  end if;

  -- Casa de Oração
  begin v_casa := (d ->> 'casa_oracao_id')::uuid; exception when others then v_casa := null; end;
  if v_casa is null or not exists (select 1 from public.casas_oracao c where c.id = v_casa and c.ativo) then
    raise exception 'Escolha a sua Casa de Oração.';
  end if;

  -- Cargo, categoria e instrumento
  begin v_cargo_id := (d ->> 'cargo_id')::uuid; exception when others then v_cargo_id := null; end;
  select c.* into v_cargo from public.cargos c where c.id = v_cargo_id;
  if not found or not public.cargo_aceita_cadastro_publico(v_cargo.nome) then
    raise exception 'Escolha um cargo da lista.';
  end if;
  v_usa_categ := public.normalizar_texto(v_cargo.nome) ~ '^(musico|organista)';
  v_categoria := nullif(btrim(d ->> 'categoria'), '');
  if v_usa_categ then
    if v_categoria is null or v_categoria not in ('OFICIALIZADO', 'CULTO_OFICIAL', 'RJM') then
      raise exception 'Escolha a categoria.';
    end if;
  else
    v_categoria := null;
  end if;

  if v_cargo.permite_instrumento then
    begin v_instr := (d ->> 'instrumento_id')::uuid; exception when others then v_instr := null; end;
    select i.nome into v_instr_nome from public.instrumentos i where i.id = v_instr;
    if v_instr_nome is null then
      raise exception 'Informe o instrumento.';
    end if;
    if v_cargo.somente_orgao and not public.instrumento_e_orgao(v_instr_nome) then
      raise exception 'O cargo % só pode usar o instrumento Órgão.', v_cargo.nome;
    end if;
  else
    v_instr := null;
  end if;

  -- Dados pessoais (mesmas regras de salvar_cadastro_musical)
  v_cad := d -> 'cadastro';
  if v_cad is null or jsonb_typeof(v_cad) <> 'object' then
    raise exception 'Preencha os dados pessoais.';
  end if;
  v_ec    := nullif(btrim(v_cad ->> 'estado_civil'), '');
  v_sx    := nullif(btrim(v_cad ->> 'sexo'), '');
  v_ddd   := nullif(btrim(v_cad ->> 'ddd'), '');
  v_tel   := nullif(btrim(v_cad ->> 'telefone'), '');
  v_wpp   := nullif(btrim(v_cad ->> 'whatsapp'), '');
  v_email := nullif(btrim(v_cad ->> 'email'), '');
  v_cep   := nullif(btrim(v_cad ->> 'cep'), '');
  v_end   := public.limpar_espacos(v_cad ->> 'endereco');
  v_num   := public.limpar_espacos(v_cad ->> 'numero');
  v_comp  := public.limpar_espacos(v_cad ->> 'complemento');
  v_uf    := nullif(btrim(v_cad ->> 'uf'), '');
  v_cnum  := public.limpar_espacos(v_cad ->> 'cartao_numero');
  v_demi  := public.data_ou_nula(v_cad ->> 'cartao_emissao');
  v_dval  := public.data_ou_nula(v_cad ->> 'cartao_validade');
  v_dbat  := public.data_ou_nula(v_cad ->> 'data_batismo');

  if v_ec is null or v_ec not in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)') then raise exception 'Informe o estado civil.'; end if;
  if v_sx is null or v_sx not in ('Masculino', 'Feminino') then raise exception 'Informe o sexo.'; end if;
  if jsonb_typeof(v_cad -> 'batizado') <> 'boolean' then raise exception 'Informe se a pessoa é batizada.'; end if;
  v_batizado := (v_cad ->> 'batizado')::boolean;
  if v_batizado then
    if v_dbat is null then raise exception 'Informe a data do batismo.'; end if;
    if v_dbat < v_nasc or v_dbat > current_date then raise exception 'A data do batismo é inválida.'; end if;
  else
    v_dbat := null;
  end if;
  if jsonb_typeof(v_cad -> 'selado') <> 'boolean' then raise exception 'Informe se a pessoa é selada.'; end if;
  if v_ddd is null or v_ddd !~ '^[0-9]{2}$' then raise exception 'O DDD deve ter 2 números.'; end if;
  if v_tel is null or v_tel !~ '^[0-9]{8,9}$' then raise exception 'O telefone deve ter 8 ou 9 números.'; end if;
  if jsonb_typeof(v_cad -> 'tem_whatsapp') <> 'boolean' then raise exception 'Informe se o telefone tem WhatsApp.'; end if;
  if (v_cad ->> 'tem_whatsapp')::boolean then
    if v_wpp is not null and v_wpp !~ '^[0-9]{10,11}$' then raise exception 'O WhatsApp deve ter o DDD e 8 ou 9 números.'; end if;
  else
    v_wpp := null;
  end if;
  if v_email is not null and (char_length(v_email) > 120 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then
    raise exception 'O e-mail informado não é válido.';
  end if;
  if v_cep is null or v_cep !~ '^[0-9]{8}$' then raise exception 'O CEP deve ter 8 números.'; end if;
  if v_end is null or char_length(v_end) > 150 then raise exception 'Informe o endereço.'; end if;
  if v_num is null or char_length(v_num) > 20 then raise exception 'Informe o número do endereço.'; end if;
  if v_comp is not null and char_length(v_comp) > 80 then raise exception 'O complemento é longo demais.'; end if;
  if v_uf is null or v_uf !~ '^[A-Z]{2}$' then raise exception 'Informe o estado (UF).'; end if;
  if v_cnum is not null and char_length(v_cnum) > 40 then raise exception 'O número do cartão é longo demais.'; end if;
  if v_demi is not null and v_dval is not null and v_demi > v_dval then
    raise exception 'A validade do cartão não pode ser anterior à emissão.';
  end if;
  if coalesce(v_cargo.exige_cartao, false) and (v_cnum is null or v_dval is null) then
    raise exception 'Este cargo exige o número e a validade do cartão de identificação.';
  end if;

  -- Menor de 18 anos: responsável
  v_menor := v_nasc > (current_date - interval '18 years')::date;
  v_resp_nome := null; v_resp_tel := null; v_ace_resp := false;
  if v_menor then
    v_resp_nome := public.limpar_espacos(d ->> 'responsavel_nome');
    v_resp_tel  := nullif(btrim(d ->> 'responsavel_telefone'), '');
    v_ace_resp  := d -> 'aceite_responsavel' is not distinct from 'true'::jsonb;
    if v_resp_nome is null or char_length(v_resp_nome) < 3 or char_length(v_resp_nome) > 120 then
      raise exception 'Para menores de 18 anos, informe o nome do responsável.';
    end if;
    if v_resp_tel is null or v_resp_tel !~ '^[0-9]{10,11}$' then
      raise exception 'Informe o telefone do responsável com o DDD.';
    end if;
    if not v_ace_resp then raise exception 'O responsável precisa concordar com o cadastro.'; end if;
  end if;

  -- Limite por CPF (3 por dia). Só conta a quantidade: não revela se o CPF existe.
  perform public.cadastro_publico_limite('cpf', encode(sha256(convert_to(v_cpf, 'UTF8')), 'hex'), 3, interval '1 day');

  -- É alguém que já está no sistema? CPF + data de nascimento iguais = pedido de ATUALIZAÇÃO.
  select m.id, m.data_nascimento into v_membro, v_membro_nasc
    from public.membros m where m.cpf = v_cpf and m.excluido_em is null;
  if found then
    if v_membro_nasc is not distinct from v_nasc then
      v_tipo := 'ATUALIZACAO';
    else
      v_conflito := true;   -- mesmo CPF, outra data de nascimento: o aprovador confere
      v_membro := null;
    end if;
  else
    v_membro := null;
  end if;

  v_limpo := jsonb_build_object(
    'estado_civil', v_ec, 'sexo', v_sx, 'batizado', v_batizado, 'data_batismo', v_dbat,
    'selado', (v_cad ->> 'selado')::boolean, 'ddd', v_ddd, 'telefone', v_tel,
    'tem_whatsapp', (v_cad ->> 'tem_whatsapp')::boolean, 'whatsapp', v_wpp, 'email', v_email,
    'cep', v_cep, 'endereco', v_end, 'numero', v_num, 'complemento', v_comp, 'uf', v_uf,
    'cartao_numero', v_cnum, 'cartao_emissao', v_demi, 'cartao_validade', v_dval);

  insert into public.cadastros_pendentes (
    id, tipo, membro_id, casa_oracao_id, nome, cpf, data_nascimento, cidade, bairro, cargo_id, instrumento_id,
    categoria, dados, responsavel_nome, responsavel_telefone, aceite_responsavel, aviso_versao, ip_hash, cpf_conflito)
  values (
    p_envio, v_tipo, v_membro, v_casa, v_nome, v_cpf, v_nasc, v_cidade, v_bairro, v_cargo_id, v_instr,
    v_categoria, v_limpo, v_resp_nome, v_resp_tel, v_ace_resp, v_aviso, p_ip_hash, v_conflito);

  update public.cadastro_publico_uploads set usado = true where id = p_envio;
end;
$$;

-- Limpeza diária (chamada pelo cron /api/cron/conferir). Devolve as pastas cujos arquivos o servidor deve apagar.
--   * envios abandonados há mais de 24 h (as linhas só saem depois que o servidor apagar os arquivos);
--   * pendentes vencidos (60 dias) viram EXPIRADO;
--   * recusados há mais de 30 dias e expirados/substituídos: arquivos apagados e dados pessoais zerados;
--   * registros de limite e linhas antigas sem dados são removidos.
create or replace function public.limpeza_cadastro_publico()
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_abandonados uuid[];
  v_pastas      uuid[];
begin
  select coalesce(array_agg(u.id), '{}') into v_abandonados
    from public.cadastro_publico_uploads u
   where not u.usado and u.criado_em < now() - interval '24 hours';

  update public.cadastros_pendentes
     set status = 'EXPIRADO', decidido_em = now()
   where status = 'PENDENTE' and expira_em < now();

  select coalesce(array_agg(c.id), '{}') into v_pastas
    from public.cadastros_pendentes c
   where c.arquivos_apagados_em is null
     and ((c.status in ('EXPIRADO', 'SUBSTITUIDO'))
          or (c.status = 'REJEITADO' and c.decidido_em < now() - interval '30 days'));

  delete from public.cadastro_publico_limites where criado_em < now() - interval '2 days';
  delete from public.cadastro_publico_uploads where usado and criado_em < now() - interval '7 days';
  delete from public.cadastros_pendentes
   where status in ('REJEITADO', 'EXPIRADO', 'SUBSTITUIDO') and arquivos_apagados_em is not null
     and decidido_em < now() - interval '180 days';

  return jsonb_build_object('pastas', to_jsonb(v_abandonados || v_pastas), 'para_marcar', to_jsonb(v_pastas),
                            'abandonados', to_jsonb(v_abandonados));
end;
$$;

-- Depois que o servidor apagou os arquivos: zera os dados pessoais dos pedidos não aprovados.
create or replace function public.marcar_cadastros_limpos(p_ids uuid[], p_abandonados uuid[] default '{}')
returns integer
language plpgsql security definer set search_path to 'public'
as $$
declare v_n integer;
begin
  delete from public.cadastro_publico_uploads where id = any (p_abandonados) and not usado;
  update public.cadastros_pendentes
     set arquivos_apagados_em = now(), nome = null, cpf = null, data_nascimento = null, cidade = null, bairro = null,
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null
   where id = any (p_ids) and status in ('REJEITADO', 'EXPIRADO', 'SUBSTITUIDO') and arquivos_apagados_em is null;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Funções do PAINEL (quem tem a permissão e a abrangência)
-- ---------------------------------------------------------------------------
-- O pedido é visível se a casa pedida OU a casa atual do membro estiver na abrangência de quem consulta.
create or replace function public.cadastro_pendente_visivel(p_casa uuid, p_membro uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select public.casa_oracao_na_abrangencia(p_casa)
      or exists (select 1 from public.membros m
                  where m.id = p_membro and m.casa_oracao_id is not null
                    and public.casa_oracao_na_abrangencia(m.casa_oracao_id))
$$;

create or replace function public.contar_cadastros_pendentes()
returns integer
language plpgsql stable security definer set search_path to 'public'
as $$
declare v_qtd integer;
begin
  if not public.tem_permissao('cadastros.visualizar') then return 0; end if;
  select count(*) into v_qtd from public.cadastros_pendentes c
   where c.status = 'PENDENTE' and public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id);
  return v_qtd;
end;
$$;

create or replace function public.listar_cadastros_pendentes(p_status text default 'PENDENTE')
returns table (
  id uuid, tipo text, status text, nome text, cpf_mascarado text, cargo_nome text, casa_nome text,
  menor boolean, cpf_conflito boolean, outros_pendentes bigint, criado_em timestamptz, expira_em timestamptz,
  decidido_em timestamptz, motivo_rejeicao text
)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('cadastros.visualizar');
  if p_status is not null and p_status not in ('PENDENTE', 'APROVADO', 'REJEITADO', 'EXPIRADO', 'TODOS') then
    raise exception 'Situação inválida.' using errcode = '22023';
  end if;
  return query
    select c.id, c.tipo, c.status, c.nome, public.cpf_escondido(c.cpf), g.nome, ca.nome,
           (c.data_nascimento is not null and c.data_nascimento > (c.criado_em::date - interval '18 years')::date),
           c.cpf_conflito,
           (select count(*) from public.cadastros_pendentes o
             where o.status = 'PENDENTE' and o.id <> c.id and c.cpf is not null and o.cpf = c.cpf),
           c.criado_em, c.expira_em, c.decidido_em, c.motivo_rejeicao
      from public.cadastros_pendentes c
      left join public.cargos g on g.id = c.cargo_id
      left join public.casas_oracao ca on ca.id = c.casa_oracao_id
     where (p_status is null or p_status = 'TODOS' or c.status = p_status)
       and public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id)
     order by case when c.status = 'PENDENTE' then 0 else 1 end, c.criado_em desc
     limit 500;
end;
$$;

-- Tudo de UM pedido, mais (nas atualizações) os dados atuais do membro para a tela mostrar o que mudou.
create or replace function public.obter_cadastro_pendente(p_id uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  c      public.cadastros_pendentes%rowtype;
  v_atual jsonb := null;
  v_ver_cpf boolean;
begin
  perform public.exigir_permissao('cadastros.visualizar');
  select * into c from public.cadastros_pendentes where id = p_id;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  v_ver_cpf := public.tem_permissao('membros.cpf');

  if c.membro_id is not null then
    select jsonb_build_object(
             'nome', m.nome, 'casa_oracao_id', m.casa_oracao_id, 'casa_nome', ca.nome,
             'cargo_id', m.cargo_id, 'cargo_nome', g.nome, 'instrumento_id', m.instrumento_id, 'instrumento_nome', i.nome,
             'categoria', m.categoria, 'cidade', m.cidade, 'bairro', m.bairro, 'data_nascimento', m.data_nascimento,
             'cadastro', (select to_jsonb(mc) - 'membro_id' - 'criado_em' - 'atualizado_em' - 'documento_frente_path'
                                 - 'documento_verso_path' - 'apresentado_em' - 'apresentado_por' - 'observacao'
                            from public.membros_cadastro mc where mc.membro_id = m.id))
      into v_atual
      from public.membros m
      left join public.casas_oracao ca on ca.id = m.casa_oracao_id
      left join public.cargos g on g.id = m.cargo_id
      left join public.instrumentos i on i.id = m.instrumento_id
     where m.id = c.membro_id and m.excluido_em is null;
  end if;

  return jsonb_build_object(
    'id', c.id, 'tipo', c.tipo, 'status', c.status, 'membro_id', c.membro_id,
    'nome', c.nome, 'data_nascimento', c.data_nascimento, 'cidade', c.cidade, 'bairro', c.bairro,
    'cpf', case when v_ver_cpf then c.cpf else public.cpf_escondido(c.cpf) end,
    'cpf_completo_visivel', v_ver_cpf,
    'casa_oracao_id', c.casa_oracao_id,
    'casa_nome', (select ca.nome from public.casas_oracao ca where ca.id = c.casa_oracao_id),
    'cargo_id', c.cargo_id, 'cargo_nome', (select g.nome from public.cargos g where g.id = c.cargo_id),
    'instrumento_id', c.instrumento_id, 'instrumento_nome', (select i.nome from public.instrumentos i where i.id = c.instrumento_id),
    'categoria', c.categoria, 'dados', c.dados,
    'menor', c.data_nascimento is not null and c.data_nascimento > (c.criado_em::date - interval '18 years')::date,
    'responsavel_nome', c.responsavel_nome, 'responsavel_telefone', c.responsavel_telefone,
    'aviso_versao', c.aviso_versao, 'aceite_em', c.aceite_em, 'cpf_conflito', c.cpf_conflito,
    'criado_em', c.criado_em, 'expira_em', c.expira_em, 'decidido_em', c.decidido_em,
    'motivo_rejeicao', c.motivo_rejeicao,
    'arquivos_disponiveis', (c.arquivos_apagados_em is null and c.status in ('PENDENTE', 'REJEITADO')),
    'outros_pendentes', (select count(*) from public.cadastros_pendentes o
                          where o.status = 'PENDENTE' and o.id <> c.id and c.cpf is not null and o.cpf = c.cpf),
    'atual', v_atual);
end;
$$;

-- Aprova. O servidor já MOVEU os arquivos para as pastas finais (p_foto / p_doc_frente / p_doc_verso) antes de chamar;
-- se esta função falhar, o servidor devolve os arquivos. Devolve os caminhos antigos para o servidor apagar.
create or replace function public.aprovar_cadastro_pendente(
  p_id uuid, p_membro uuid, p_foto text, p_doc_frente text, p_doc_verso text)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  c         public.cadastros_pendentes%rowtype;
  v_cad     jsonb;
  v_membro  uuid;
  v_atual   public.membros%rowtype;
  v_antigos jsonb := '{}'::jsonb;
  v_obs     text;
  v_antigo_cad public.membros_cadastro%rowtype;
begin
  perform public.exigir_permissao('cadastros.aprovar');
  select * into c from public.cadastros_pendentes where id = p_id for update;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  if c.status <> 'PENDENTE' then
    raise exception 'Este cadastro já foi analisado.' using errcode = '22023';
  end if;
  if not public.casa_oracao_na_abrangencia(c.casa_oracao_id) then
    raise exception 'A Casa de Oração do pedido está fora da sua abrangência. Peça a quem tem acesso total.' using errcode = '42501';
  end if;

  v_membro := coalesce(c.membro_id, p_membro);
  if v_membro is null then raise exception 'Identificação do membro ausente.' using errcode = '22023'; end if;
  if left(p_foto, 37) <> v_membro::text || '/' then
    raise exception 'Caminho da fotografia inválido.' using errcode = '22023';
  end if;
  if left(p_doc_frente, 37) <> v_membro::text || '/' or left(p_doc_verso, 37) <> v_membro::text || '/' then
    raise exception 'Caminho do documento inválido.' using errcode = '22023';
  end if;
  if position('..' in p_foto || p_doc_frente || p_doc_verso) > 0 then
    raise exception 'Caminho inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = p_doc_frente)
     or not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = p_doc_verso) then
    raise exception 'Os arquivos do documento não foram encontrados. Tente aprovar de novo.' using errcode = '22023';
  end if;
  perform public.validar_foto_membro(v_membro, p_foto);

  -- A partir daqui o gatilho dos membros aceita o CPF (a permissão cadastros.aprovar já foi conferida)
  perform set_config('sysmusica.aprovando_cadastro', 'sim', true);

  v_cad := c.dados;
  v_obs := null;
  if c.responsavel_nome is not null then
    v_obs := 'Menor de idade no cadastro público (' || to_char(c.criado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY')
             || '). Responsável: ' || c.responsavel_nome || ', telefone ' || c.responsavel_telefone || '.';
  end if;

  if c.tipo = 'NOVO' then
    if c.cpf is null or exists (select 1 from public.membros m where m.cpf = c.cpf and m.excluido_em is null) then
      raise exception 'Já existe um membro com este CPF. Recuse este pedido e atualize o cadastro existente.' using errcode = '23505';
    end if;
    insert into public.membros (id, nome, congregacao, casa_oracao_id, cargo_id, data_nascimento, status,
                                instrumento_id, cpf, cidade, bairro, foto_path, categoria)
    values (v_membro, c.nome, '', c.casa_oracao_id, c.cargo_id, c.data_nascimento, 'Ativo',
            c.instrumento_id, c.cpf, c.cidade, c.bairro, p_foto, c.categoria);

    insert into public.membros_cadastro (
      membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
      cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade, observacao,
      documento_frente_path, documento_verso_path)
    values (
      v_membro, v_cad ->> 'estado_civil', v_cad ->> 'sexo', (v_cad ->> 'batizado')::boolean,
      public.data_ou_nula(v_cad ->> 'data_batismo'), (v_cad ->> 'selado')::boolean, v_cad ->> 'ddd', v_cad ->> 'telefone',
      (v_cad ->> 'tem_whatsapp')::boolean, v_cad ->> 'whatsapp', v_cad ->> 'email',
      v_cad ->> 'cep', v_cad ->> 'endereco', v_cad ->> 'numero', v_cad ->> 'complemento', v_cad ->> 'uf',
      v_cad ->> 'cartao_numero', public.data_ou_nula(v_cad ->> 'cartao_emissao'),
      public.data_ou_nula(v_cad ->> 'cartao_validade'), v_obs, p_doc_frente, p_doc_verso);
  else
    select * into v_atual from public.membros m where m.id = v_membro and m.excluido_em is null for update;
    if not found then
      raise exception 'O membro deste pedido foi excluído. Recuse o pedido.' using errcode = '22023';
    end if;
    if v_atual.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(v_atual.casa_oracao_id) then
      raise exception 'O membro está em uma Casa de Oração fora da sua abrangência. Peça a quem tem acesso total.' using errcode = '42501';
    end if;
    select * into v_antigo_cad from public.membros_cadastro where membro_id = v_membro;
    v_antigos := jsonb_build_object('foto', v_atual.foto_path,
                                    'doc_frente', v_antigo_cad.documento_frente_path,
                                    'doc_verso', v_antigo_cad.documento_verso_path);

    update public.membros
       set nome = c.nome, casa_oracao_id = c.casa_oracao_id, cargo_id = c.cargo_id, instrumento_id = c.instrumento_id,
           categoria = c.categoria, cidade = c.cidade, bairro = c.bairro, foto_path = p_foto
     where id = v_membro;

    insert into public.membros_cadastro as mc (
      membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
      cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade, observacao,
      documento_frente_path, documento_verso_path)
    values (
      v_membro, v_cad ->> 'estado_civil', v_cad ->> 'sexo', (v_cad ->> 'batizado')::boolean,
      public.data_ou_nula(v_cad ->> 'data_batismo'), (v_cad ->> 'selado')::boolean, v_cad ->> 'ddd', v_cad ->> 'telefone',
      (v_cad ->> 'tem_whatsapp')::boolean, v_cad ->> 'whatsapp', v_cad ->> 'email',
      v_cad ->> 'cep', v_cad ->> 'endereco', v_cad ->> 'numero', v_cad ->> 'complemento', v_cad ->> 'uf',
      v_cad ->> 'cartao_numero', public.data_ou_nula(v_cad ->> 'cartao_emissao'),
      public.data_ou_nula(v_cad ->> 'cartao_validade'), v_obs, p_doc_frente, p_doc_verso)
    on conflict (membro_id) do update set
      estado_civil = excluded.estado_civil, sexo = excluded.sexo, batizado = excluded.batizado,
      data_batismo = excluded.data_batismo, selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
      tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email, cep = excluded.cep,
      endereco = excluded.endereco, numero = excluded.numero, complemento = excluded.complemento, uf = excluded.uf,
      cartao_numero = excluded.cartao_numero, cartao_emissao = excluded.cartao_emissao,
      cartao_validade = excluded.cartao_validade,
      -- menor de idade: acrescenta a anotação do responsável sem apagar a observação que já existia
      observacao = case when excluded.observacao is null then mc.observacao
                        when mc.observacao is null then excluded.observacao
                        else mc.observacao || E'\n' || excluded.observacao end,
      documento_frente_path = excluded.documento_frente_path, documento_verso_path = excluded.documento_verso_path,
      atualizado_em = now();
  end if;

  -- O pedido vira histórico: os dados já estão no membro, então saem daqui (guardamos só quem decidiu e quando)
  update public.cadastros_pendentes
     set status = 'APROVADO', membro_id = v_membro, decidido_em = now(), decidido_por = (select auth.uid()),
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null,
         arquivos_apagados_em = now()
   where id = p_id;

  perform public.registrar_auditoria('cadastro_aprovado', 'cadastro_pendente', p_id,
            jsonb_build_object('tipo', c.tipo, 'membro_id', v_membro, 'rotulo', c.nome));
  perform set_config('sysmusica.aprovando_cadastro', '', true);
  return jsonb_build_object('membro_id', v_membro, 'tipo', c.tipo, 'antigos', v_antigos);
end;
$$;

create or replace function public.rejeitar_cadastro_pendente(p_id uuid, p_motivo text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  c       public.cadastros_pendentes%rowtype;
  v_motivo text := public.limpar_espacos(p_motivo);
begin
  perform public.exigir_permissao('cadastros.aprovar');
  if v_motivo is null or char_length(v_motivo) < 5 then
    raise exception 'Informe o motivo da recusa (pelo menos 5 letras).' using errcode = '22023';
  end if;
  if char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 caracteres.' using errcode = '22023';
  end if;
  select * into c from public.cadastros_pendentes where id = p_id for update;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  if c.status <> 'PENDENTE' then
    raise exception 'Este cadastro já foi analisado.' using errcode = '22023';
  end if;
  update public.cadastros_pendentes
     set status = 'REJEITADO', motivo_rejeicao = v_motivo, decidido_em = now(), decidido_por = (select auth.uid())
   where id = p_id;
  perform public.registrar_auditoria('cadastro_rejeitado', 'cadastro_pendente', p_id,
            jsonb_build_object('tipo', c.tipo, 'motivo', v_motivo, 'rotulo', c.nome));
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Quem pode chamar
-- ---------------------------------------------------------------------------
revoke all on function public.cargo_aceita_cadastro_publico(text) from public, anon, authenticated;
revoke all on function public.data_ou_nula(text) from public, anon, authenticated;
revoke all on function public.cpf_escondido(text) from public, anon, authenticated;
revoke all on function public.cadastro_publico_limite(text, text, integer, interval) from public, anon, authenticated;
revoke all on function public.cadastro_pendente_visivel(uuid, uuid) from public, anon, authenticated;
revoke all on function public.opcoes_cadastro_publico() from public, anon, authenticated;
revoke all on function public.iniciar_envio_publico(text) from public, anon, authenticated;
revoke all on function public.registrar_cadastro_publico(uuid, jsonb, text) from public, anon, authenticated;
revoke all on function public.limpeza_cadastro_publico() from public, anon, authenticated;
revoke all on function public.marcar_cadastros_limpos(uuid[], uuid[]) from public, anon, authenticated;
revoke all on function public.contar_cadastros_pendentes() from public, anon, authenticated;
revoke all on function public.listar_cadastros_pendentes(text) from public, anon, authenticated;
revoke all on function public.obter_cadastro_pendente(uuid) from public, anon, authenticated;
revoke all on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.rejeitar_cadastro_pendente(uuid, text) from public, anon, authenticated;

-- Funções de apoio chamadas por outras funções (security definer) não precisam de grant; a data/CPF não vazam nada.
grant execute on function public.opcoes_cadastro_publico() to anon, authenticated;
grant execute on function public.iniciar_envio_publico(text) to service_role;
grant execute on function public.registrar_cadastro_publico(uuid, jsonb, text) to service_role;
grant execute on function public.limpeza_cadastro_publico() to service_role;
grant execute on function public.marcar_cadastros_limpos(uuid[], uuid[]) to service_role;
grant execute on function public.contar_cadastros_pendentes() to authenticated;
grant execute on function public.listar_cadastros_pendentes(text) to authenticated;
grant execute on function public.obter_cadastro_pendente(uuid) to authenticated;
grant execute on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.rejeitar_cadastro_pendente(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Backup: a função de restauração passa a aceitar cadastros_pendentes e membros_cadastro
--     (cópia da versão da migração 0041 com duas linhas novas na lista permitida)
-- ---------------------------------------------------------------------------
create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('tipos_evento',        array['id'],                              false, false, ''),
      ('hinos',               array['id'],                              false, false, ''),
      ('cadastros_pendentes', array['id'],                              false, false, ''),
      ('membros_cadastro',    array['membro_id'],                       false, false, ''),
      ('dados_ensaio',        array['id'],                              false, false, ''),
      ('dados_ensaio_encarregados', array['id'],                        false, false, ''),
      ('dados_ensaio_hinos',  array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Conferência final
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.cadastros_pendentes') is null
     or (select count(*) from public.permissoes where codigo in ('cadastros.visualizar', 'cadastros.aprovar')) <> 2
     or not exists (select 1 from storage.buckets where id = 'cadastro-publico' and not public)
     or to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text)') is null
     or to_regprocedure('public.opcoes_cadastro_publico()') is null then
    raise exception 'Teste falhou: objetos da Parte 9 ausentes. Nada foi alterado.';
  end if;
  raise notice 'OK: cadastro público e fila de cadastros pendentes instalados.';
end $$;

select set_config('sysmusica.restaurando', '', true);
commit;
