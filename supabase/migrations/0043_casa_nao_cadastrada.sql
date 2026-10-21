-- =============================================================================
-- SysMúsica — Migração 0043: Cadastro público com Casa de Oração que NÃO está cadastrada
--
-- Antes: o formulário público exigia escolher uma Casa de Oração da lista.
-- Agora: a pessoa pode digitar o nome da casa; o pedido entra em "Cadastros pendentes" marcado como
-- "Casa não cadastrada" e quem aprova escolhe a casa correta (ou cadastra antes em Organização).
--
--   * cadastros_pendentes.casa_oracao_id passa a aceitar nulo; nova coluna casa_nome_informada (o texto digitado).
--   * Pedido SEM casa só é visível para quem tem acesso total à organização (não dá para saber de que região é)
--     — ou, nas atualizações, para quem enxerga a casa atual do membro.
--   * aprovar_cadastro_pendente ganha o parâmetro p_casa (obrigatório quando o pedido não tem casa).
--   * listar_cadastros_pendentes ganha a coluna casa_nao_cadastrada.
--   * A limpeza automática também apaga o nome digitado.
-- Rode UMA vez no SQL Editor do Supabase (depois da 0042).
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.cadastros_pendentes') is null then
    raise exception 'Aplique primeiro a migração 0042. Nada foi alterado.';
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'cadastros_pendentes' and column_name = 'casa_nome_informada') then
    raise exception 'A migração 0043 já foi aplicada. Nada foi alterado.';
  end if;
  if to_regprocedure('public.tem_acesso_total_organizacao()') is null then
    raise exception 'Função tem_acesso_total_organizacao não encontrada. Nada foi alterado.';
  end if;
end $$;

-- 1. Tabela
alter table public.cadastros_pendentes alter column casa_oracao_id drop not null;
alter table public.cadastros_pendentes
  add column casa_nome_informada text
  check (casa_nome_informada is null or char_length(casa_nome_informada) between 3 and 120);

-- 2. Visibilidade: sem casa => só acesso total à organização (ou a casa atual do membro, nas atualizações)
create or replace function public.cadastro_pendente_visivel(p_casa uuid, p_membro uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select (p_casa is null and public.tem_acesso_total_organizacao())
      or (p_casa is not null and public.casa_oracao_na_abrangencia(p_casa))
      or exists (select 1 from public.membros m
                  where m.id = p_membro and m.casa_oracao_id is not null
                    and public.casa_oracao_na_abrangencia(m.casa_oracao_id))
$$;

-- 3. Envio público
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
  v_casa_txt     text;
  v_casa_nome    text;
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
  -- Dois caminhos: (a) escolheu uma casa da lista (id); (b) a casa não existe na lista e a pessoa digitou o nome.
  -- No caso (b) o pedido fica sem casa; quem aprova escolhe (ou cadastra) a casa correta antes de aprovar.
  v_casa_txt := nullif(btrim(d ->> 'casa_oracao_id'), '');
  v_casa := null;
  v_casa_nome := null;
  if v_casa_txt is not null then
    begin v_casa := v_casa_txt::uuid; exception when others then v_casa := null; end;
    if v_casa is null or not exists (select 1 from public.casas_oracao c where c.id = v_casa and c.ativo) then
      raise exception 'Escolha a sua Casa de Oração na lista ou digite o nome dela.';
    end if;
  else
    v_casa_nome := public.limpar_espacos(d ->> 'casa_nome');
    if v_casa_nome is null or char_length(v_casa_nome) < 3 or char_length(v_casa_nome) > 120 then
      raise exception 'Escolha a sua Casa de Oração na lista ou digite o nome dela.';
    end if;
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
    id, tipo, membro_id, casa_oracao_id, casa_nome_informada, nome, cpf, data_nascimento, cidade, bairro, cargo_id, instrumento_id,
    categoria, dados, responsavel_nome, responsavel_telefone, aceite_responsavel, aviso_versao, ip_hash, cpf_conflito)
  values (
    p_envio, v_tipo, v_membro, v_casa, v_casa_nome, v_nome, v_cpf, v_nasc, v_cidade, v_bairro, v_cargo_id, v_instr,
    v_categoria, v_limpo, v_resp_nome, v_resp_tel, v_ace_resp, v_aviso, p_ip_hash, v_conflito);

  update public.cadastro_publico_uploads set usado = true where id = p_envio;
end;
$$;

-- 4. Lista (mudou a lista de colunas devolvidas: precisa apagar e recriar)
drop function public.listar_cadastros_pendentes(text);
create function public.listar_cadastros_pendentes(p_status text default 'PENDENTE')
returns table (
  id uuid, tipo text, status text, nome text, cpf_mascarado text, cargo_nome text, casa_nome text,
  casa_nao_cadastrada boolean,
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
    select c.id, c.tipo, c.status, c.nome, public.cpf_escondido(c.cpf), g.nome,
           coalesce(ca.nome, c.casa_nome_informada),
           (c.casa_oracao_id is null and c.casa_nome_informada is not null),
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
revoke all on function public.listar_cadastros_pendentes(text) from public, anon, authenticated;
grant execute on function public.listar_cadastros_pendentes(text) to authenticated;

-- 5. Detalhe
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
    'casa_nome', coalesce((select ca.nome from public.casas_oracao ca where ca.id = c.casa_oracao_id), c.casa_nome_informada),
    'casa_nome_informada', c.casa_nome_informada,
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

-- 6. Aprovação (nova assinatura com p_casa; a antiga é removida)
drop function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text);
create function public.aprovar_cadastro_pendente(
  p_id uuid, p_membro uuid, p_foto text, p_doc_frente text, p_doc_verso text, p_casa uuid default null)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  c         public.cadastros_pendentes%rowtype;
  v_cad     jsonb;
  v_membro  uuid;
  v_casa    uuid;
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
  -- Pedido com Casa de Oração DIGITADA (não estava na lista): quem aprova escolhe a casa cadastrada correta.
  v_casa := c.casa_oracao_id;
  if v_casa is null then
    v_casa := p_casa;
    if v_casa is null then
      raise exception 'Este pedido trouxe uma Casa de Oração que não está cadastrada. Escolha a casa correta (ou cadastre-a em Organização) antes de aprovar.' using errcode = '22023';
    end if;
    if not exists (select 1 from public.casas_oracao x where x.id = v_casa and x.ativo) then
      raise exception 'Casa de Oração inválida ou inativa.' using errcode = '22023';
    end if;
  end if;
  if not public.casa_oracao_na_abrangencia(v_casa) then
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
    values (v_membro, c.nome, '', v_casa, c.cargo_id, c.data_nascimento, 'Ativo',
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
       set nome = c.nome, casa_oracao_id = v_casa, cargo_id = c.cargo_id, instrumento_id = c.instrumento_id,
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
     set status = 'APROVADO', membro_id = v_membro, casa_oracao_id = v_casa, casa_nome_informada = null, decidido_em = now(), decidido_por = (select auth.uid()),
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null,
         arquivos_apagados_em = now()
   where id = p_id;

  perform public.registrar_auditoria('cadastro_aprovado', 'cadastro_pendente', p_id,
            jsonb_build_object('tipo', c.tipo, 'membro_id', v_membro, 'rotulo', c.nome));
  perform set_config('sysmusica.aprovando_cadastro', '', true);
  return jsonb_build_object('membro_id', v_membro, 'tipo', c.tipo, 'antigos', v_antigos);
end;
$$;
revoke all on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid) to authenticated;

-- 7. Limpeza
create or replace function public.marcar_cadastros_limpos(p_ids uuid[], p_abandonados uuid[] default '{}')
returns integer
language plpgsql security definer set search_path to 'public'
as $$
declare v_n integer;
begin
  delete from public.cadastro_publico_uploads where id = any (p_abandonados) and not usado;
  update public.cadastros_pendentes
     set arquivos_apagados_em = now(), casa_nome_informada = null, nome = null, cpf = null, data_nascimento = null, cidade = null, bairro = null,
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null
   where id = any (p_ids) and status in ('REJEITADO', 'EXPIRADO', 'SUBSTITUIDO') and arquivos_apagados_em is null;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- 8. Conferência final
do $$
begin
  if to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid)') is null
     or to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text)') is not null then
    raise exception 'Falha ao instalar a nova função de aprovação. Nada foi alterado.';
  end if;
  if has_function_privilege('anon', 'public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid)', 'execute')
     or has_function_privilege('anon', 'public.listar_cadastros_pendentes(text)', 'execute')
     or has_function_privilege('anon', 'public.registrar_cadastro_publico(uuid, jsonb, text)', 'execute') then
    raise exception 'Permissões inesperadas para o papel anon. Nada foi alterado.';
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0043', 'ok', false);
