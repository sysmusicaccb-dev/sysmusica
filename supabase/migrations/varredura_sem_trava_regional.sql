-- VARREDURA (somente leitura, não grava nada): funções que mexem em dados de uma região SEM trava regional.
-- Rode no SQL Editor e me envie o resultado inteiro (exportar CSV). Serve para planejar a Etapa 2.
--
-- Coluna "situacao":
--   SEM_TRAVA  = mexe em tabela regional, é chamável pelo navegador e não cita nenhuma regra de região (PRIORIDADE)
--   TRAVA_INDIRETA = não cita região no próprio código, mas chama outra função que pode checar (conferir)
--   COM_TRAVA  = já checa região
-- Gatilhos (triggers) e funções auxiliares internas ficam de fora.

with regionais as (
  select unnest(array['eventos','membros','portarias','presencas','presencas_avulsas','dados_ensaio',
                      'cadastros_pendentes','membros_cadastro','casas_oracao','usuarios','usuario_vinculos',
                      'auditoria','portarias_historico']) as tabela
), funcoes as (
  select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args,
         p.prosecdef, p.prorettype, lower(p.prosrc) as src
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.prokind = 'f'
     and p.prorettype <> 'trigger'::regtype
     and has_function_privilege('authenticated', p.oid, 'execute')   -- o navegador consegue chamar
), analise as (
  select f.*,
         (select string_agg(r.tabela, ',' order by r.tabela) from regionais r
           where f.src ~ ('(from|join|update|into|delete from)\s+(public\.)?' || r.tabela || '\y')) as tabelas,
         (f.src ~ 'abrangencia' or f.src ~ 'pode_ver_portaria' or f.src ~ 'cadastro_pendente_visivel'
          or f.src ~ 'exigir_acesso_atendimento' or f.src ~ 'usuario_vinculos' or f.src ~ 'usuario_na_minha'
          or f.src ~ 'tem_acesso_total_organizacao') as cita_regiao,
         (f.src ~ 'public\.(entradas|cartao|buscar|info_entrada|obter_|listar_|relatorio|painel)[a-z_]*\(') as chama_outras,
         (select string_agg(distinct m[1], ', ')
            from regexp_matches(f.src, '(?:exigir_permissao|tem_permissao|exigir_alguma_permissao|tem_alguma_permissao)\(\s*(?:array\[)?\s*''([a-z_.]+)''', 'g') m) as permissoes_exigidas,
         (f.src ~ 'excluido_em is null' ) as filtra_excluidos
    from funcoes f
)
select a.proname as funcao,
       a.args as argumentos,
       case when a.cita_regiao then 'COM_TRAVA'
            when a.tabelas is not null and a.chama_outras then 'TRAVA_INDIRETA'
            when a.tabelas is not null then 'SEM_TRAVA'
            else 'NAO_REGIONAL' end as situacao,
       coalesce(a.tabelas, '') as tabelas_que_toca,
       coalesce(a.permissoes_exigidas, '(nenhuma)') as permissoes_exigidas,
       case when a.args ~* '(^|, )p_(id|evento|evento_id|portaria|portaria_id|membro|membro_id|casa|casa_oracao|usuario)\w* uuid' then 'por ID' else '' end as recebe_id
  from analise a
 where a.tabelas is not null or a.cita_regiao
 order by case when a.cita_regiao then 3 when a.tabelas is not null and a.chama_outras then 2 else 1 end,
          a.proname;
