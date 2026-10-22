-- 0052 — Painel ao Vivo: só mostra evento que tem PORTARIA APROVADA (pronta para registrar entradas).
-- Regra: evento não excluído, não cancelado, não encerrado à mão, dentro da janela (2h antes até 3h depois)
-- e com portaria aprovada. Evento encerrado à mão já bloqueia as entradas (gatilhos da 0051) e some do painel.
-- Seguro rodar mais de uma vez.
CREATE OR REPLACE FUNCTION public.eventos_do_painel()
 RETURNS TABLE(id uuid, tipo text, local_evento text, data_evento timestamp with time zone, cidade text, casa_oracao_nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('painel.visualizar');
  return query
    select e.id, e.tipo, e.local, e.data_evento, e.cidade, c.nome
      from public.eventos e
      left join public.casas_oracao c on c.id = e.casa_oracao_id
     where e.excluido_em is null
       and e.cancelado_em is null
       and e.encerrado_em is null
       and public.portaria_janela_aberta(e.data_evento)
       -- portaria criada E aprovada para o evento
       and exists (select 1 from public.portarias p
                    where p.evento_id = e.id and p.status = 'APROVADA' and p.excluido_em is null)
       and public.evento_na_abrangencia(e.id)
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$function$;

do $$
begin
  if (select prosrc from pg_proc where oid = 'public.eventos_do_painel()'::regprocedure) not like '%APROVADA%' then
    raise exception 'Verificação falhou: o painel não foi atualizado.';
  end if;
end $$;
