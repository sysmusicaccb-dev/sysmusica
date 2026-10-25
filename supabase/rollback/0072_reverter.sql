-- Desfaz o 0072 (remove só a função que devolve os dados do cadastro para as fichas).
drop function if exists public.dados_do_membro_para_ficha(uuid);
