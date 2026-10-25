-- TESTE da 0063 — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.
create or replace function pg_temp.tenta(p_sql text) returns text language plpgsql as $f$
begin
  begin execute p_sql; raise exception using errcode = 'XX999', message = '__ok__';
  exception when others then return case when sqlerrm = '__ok__' then 'OK' else sqlerrm end; end;
end $f$;

create or replace function pg_temp.teste63()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_lev uuid; v_jer uuid; v_sp uuid; v_g uuid; v_adm_ita uuid; v_adm_sp uuid; v_casa_ita uuid; v_casa_sp uuid;
  v_cod text; v_cod2 text; v_p int := 0; v_ped_com uuid := gen_random_uuid(); v_ped_sem uuid := gen_random_uuid();
  v_env uuid := gen_random_uuid(); v_dados jsonb; v_cargo uuid; v_instr uuid;
begin
  select u.id into v_lev from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_sp  from public.usuarios u where lower(u.email) = 'sp@x.org';
  begin
    -- Dá aos dois regionais as permissões de cadastro (só dentro do teste)
    -- (só dentro do teste) concede as permissões de cadastro a TODOS os grupos dos usuários regionais
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
    select g.gid, p.cod
      from (select ug.grupo_id as gid from public.usuario_grupos ug where ug.usuario_id in (v_jer, coalesce(v_sp, v_jer))
            union select u.grupo_id from public.usuarios u where u.id in (v_jer, coalesce(v_sp, v_jer))) g
     cross join (values ('cadastros.aprovar'), ('cadastros.visualizar')) p(cod)
     where g.gid is not null
    on conflict do nothing;

    -- ===== Jerrivan (RRM Itabuna) =====
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);

    -- ADM da região do Jerrivan (a primeira, na abrangência dele, que tenha casa ativa)
    select a.id into v_adm_ita from public.adms a
     where a.ativo and public.alvo_na_minha_abrangencia('ADM', a.id)
       and exists (select 1 from public.casas_oracao c where c.ativo and public.casa_na_regiao_do_link(c.id, 'ADM', a.id))
     order by a.nome limit 1;
    -- Alvos de OUTRA região: qualquer ADM/casa ativa fora da abrangência do Jerrivan
    select a.id into v_adm_sp from public.adms a where a.ativo and not public.alvo_na_minha_abrangencia('ADM', a.id) limit 1;
    select c.id into v_casa_sp from public.casas_oracao c where c.ativo and not public.casa_oracao_na_abrangencia(c.id) limit 1;
    select c.id into v_casa_ita from public.casas_oracao c where c.ativo and public.casa_oracao_na_abrangencia(c.id) limit 1;

    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan cria link da ADM da região dele'; esperado := 'OK';
    begin v_cod := public.criar_link_cadastro('ADM', v_adm_ita) ->> 'codigo'; obtido := 'OK'; exception when others then obtido := sqlerrm; end;
    resultado := case when obtido = esperado and length(v_cod) = 32 then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Criar de novo devolve o MESMO link (não duplica)'; esperado := 'true';
    v_cod2 := public.criar_link_cadastro('ADM', v_adm_ita) ->> 'codigo'; obtido := (v_cod2 = v_cod)::text;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan tenta criar link da ADM de OUTRA região'; esperado := 'Esta região está fora da sua abrangência.';
    obtido := case when v_adm_sp is null then esperado else
              pg_temp.tenta(format('select public.criar_link_cadastro(%L, %L)', 'ADM', v_adm_sp)) end;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Nível inválido (SETOR) é recusado'; esperado := 'Escolha a região do link (RRM, RA ou ADM).';
    obtido := pg_temp.tenta(format('select public.criar_link_cadastro(%L, %L)', 'SETOR', v_adm_ita));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan lista só links da região dele'; esperado := '1';
    select count(*)::text into obtido from public.listar_links_cadastro();
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    -- ===== Opções do formulário (chamada pública, sem login) =====
    perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
    v_p := v_p+1; ordem := v_p; verificacao := 'Link mostra SÓ as casas ativas da região (nenhuma de fora)';
    select count(*)::text into esperado from public.casas_oracao c where c.ativo and public.casa_na_regiao_do_link(c.id, 'ADM', v_adm_ita);
    select (count(*) filter (where public.casa_na_regiao_do_link((e ->> 'id')::uuid, 'ADM', v_adm_ita)) = count(*))::text || '/' || count(*)::text
      into obtido from jsonb_array_elements(public.opcoes_cadastro_link(v_cod) -> 'casas') e;
    obtido := case when split_part(obtido, '/', 1) = 'true' then split_part(obtido, '/', 2) else 'tem casa de fora' end;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Link inexistente devolve nulo'; esperado := 'true';
    obtido := (public.opcoes_cadastro_link('naoexiste') is null)::text;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Página geral (sem link) continua listando todas as casas ativas';
    select count(*)::text into esperado from public.casas_oracao c where c.ativo;
    obtido := jsonb_array_length(public.opcoes_cadastro_publico() -> 'casas')::text;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    -- ===== Envio pelo link =====
    select c.id into v_cargo from public.cargos c
     where c.permite_instrumento and not coalesce(c.somente_orgao, false) and not coalesce(c.exige_cartao, false)
       and public.cargo_aceita_cadastro_publico(c.nome) and public.normalizar_texto(c.nome) ~ '^(musico|organista)' limit 1;
    select i.id into v_instr from public.instrumentos i where not public.instrumento_e_orgao(i.nome) limit 1;
    insert into storage.objects (bucket_id, name) values ('cadastro-publico', v_env::text||'/foto.jpg'), ('cadastro-publico', v_env::text||'/frente.jpg'), ('cadastro-publico', v_env::text||'/verso.jpg');
    insert into public.cadastro_publico_uploads (id) values (v_env);
    v_dados := jsonb_build_object('nome','Fulano de Tal','cpf','52998224725','data_nascimento','1990-01-01','cidade','Itabuna','bairro','Centro',
      'aceite_privacidade', true,'aviso_versao','v1','cargo_id',v_cargo,'instrumento_id',v_instr,'categoria','OFICIALIZADO',
      'casa_nome','Casa Que Nao Existe',
      'cadastro', jsonb_build_object('estado_civil','Solteiro (a)','sexo','Masculino','batizado',false,'selado',false,'ddd','73','telefone','999999999',
        'tem_whatsapp',false,'cep','45600000','endereco','Rua A','numero','1','uf','BA'));

    v_p := v_p+1; ordem := v_p; verificacao := 'Envio com link inexistente é recusado'; esperado := 'Este link de cadastro não está mais ativo. Peça um link novo à sua administração.';
    obtido := pg_temp.tenta(format('select public.registrar_cadastro_publico(%L, %L::jsonb, null)', v_env, (v_dados || '{"link":"zzz"}')::text));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Casa de OUTRA região escolhida com o link é recusada'; esperado := 'A Casa de Oração escolhida não pertence à região deste link.';
    obtido := case when v_casa_sp is null then esperado else
              pg_temp.tenta(format('select public.registrar_cadastro_publico(%L, %L::jsonb, null)', v_env,
              ((v_dados - 'casa_nome') || jsonb_build_object('link', v_cod, 'casa_oracao_id', v_casa_sp))::text)) end;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    v_p := v_p+1; ordem := v_p; verificacao := 'Envio válido com casa digitada (não cadastrada) pelo link é aceito'; esperado := 'OK';
    obtido := pg_temp.tenta(format('select public.registrar_cadastro_publico(%L, %L::jsonb, null)', v_env, (v_dados || jsonb_build_object('link', v_cod))::text));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    -- grava de verdade (dentro do teste) para conferir a marca de origem
    perform public.registrar_cadastro_publico(v_env, v_dados || jsonb_build_object('link', v_cod), null);
    v_p := v_p+1; ordem := v_p; verificacao := 'Pedido ficou marcado com a região do link'; esperado := 'ADM';
    select origem_nivel into obtido from public.cadastros_pendentes where id = v_env;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    -- Pedido de outra região, sem casa, e um sem origem nenhuma
    insert into public.cadastros_pendentes (id, nome, casa_nome_informada, origem_nivel, origem_id, aceite_em, aceite_responsavel, aviso_versao,
                                            cpf_conflito, criado_em, dados, expira_em, status, tipo)
    values (v_ped_com, 'Pedido outra região', 'Casa X', 'ADM', v_adm_sp, now(), false, 'v1', false, now(), '{}', now() + interval '30 days', 'PENDENTE', 'NOVO');
    insert into public.cadastros_pendentes (id, nome, casa_nome_informada, aceite_em, aceite_responsavel, aviso_versao,
                                            cpf_conflito, criado_em, dados, expira_em, status, tipo)
    values (v_ped_sem, 'Pedido geral', 'Casa Y', now(), false, 'v1', false, now(), '{}', now() + interval '30 days', 'PENDENTE', 'NOVO');

    -- ===== Quem vê o quê =====
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan vê o pedido do link dele'; esperado := '1';
    select count(*)::text into obtido from public.listar_cadastros_pendentes('PENDENTE') l where l.id = v_env;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan NÃO vê pedido de outra região nem o sem origem'; esperado := '0';
    select count(*)::text into obtido from public.listar_cadastros_pendentes('PENDENTE') l where l.id in (v_ped_com, v_ped_sem);
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Contador do Jerrivan = quantidade da lista dele (e inclui o pedido do link)'; 
    select count(*)::text into esperado from public.listar_cadastros_pendentes('PENDENTE');
    obtido := public.contar_cadastros_pendentes()::text;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan abre o detalhe do pedido da região dele'; esperado := 'OK';
    obtido := pg_temp.tenta(format('select public.obter_cadastro_pendente(%L)', v_env));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan não abre o detalhe do pedido de SP'; esperado := 'Cadastro não encontrado.';
    obtido := pg_temp.tenta(format('select public.obter_cadastro_pendente(%L)', v_ped_com));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan não recusa pedido de SP'; esperado := 'Cadastro não encontrado.';
    obtido := pg_temp.tenta(format('select public.rejeitar_cadastro_pendente(%L, %L)', v_ped_com, 'Motivo qualquer'));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Jerrivan recusa o pedido da região dele'; esperado := 'OK';
    obtido := pg_temp.tenta(format('select public.rejeitar_cadastro_pendente(%L, %L)', v_env, 'Motivo qualquer'));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    if v_sp is not null then
    -- ===== Usuário de SP (só existe no banco de teste) =====
    perform set_config('request.jwt.claims', json_build_object('sub', v_sp, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_sp::text, true);
    v_p := v_p+1; ordem := v_p; verificacao := 'Usuário de SP vê o pedido de SP e NÃO o de Itabuna'; esperado := '1/0';
    select (select count(*) from public.listar_cadastros_pendentes('TODOS') l where l.id = v_ped_com)::text || '/' ||
           (select count(*) from public.listar_cadastros_pendentes('TODOS') l where l.id = v_env)::text into obtido;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Usuário de SP não lista links de Itabuna'; esperado := '0';
    select count(*)::text into obtido from public.listar_links_cadastro();
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;
    v_p := v_p+1; ordem := v_p; verificacao := 'Usuário de SP não desativa link de Itabuna'; esperado := 'Link não encontrado.';
    obtido := pg_temp.tenta(format('select public.desativar_link_cadastro(%L)', (select id from public.cadastro_links limit 1)));
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    end if;

    -- ===== Administrador global =====
    perform set_config('request.jwt.claims', json_build_object('sub', v_lev, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_lev::text, true);
    v_p := v_p+1; ordem := v_p; verificacao := 'Global vê os 3 pedidos (Itabuna, SP, geral)'; esperado := '3';
    select count(*)::text into obtido from public.listar_cadastros_pendentes('TODOS') l where l.id in (v_env, v_ped_com, v_ped_sem);
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    -- ===== Desativar =====
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    perform public.desativar_link_cadastro((select id from public.cadastro_links where codigo = v_cod));
    perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
    v_p := v_p+1; ordem := v_p; verificacao := 'Link desativado deixa de abrir o formulário'; esperado := 'true';
    obtido := (public.opcoes_cadastro_link(v_cod) is null)::text;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end $f$;

select * from pg_temp.teste63();
