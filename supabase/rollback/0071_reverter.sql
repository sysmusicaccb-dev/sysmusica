-- Desfaz o 0071 (remove só a função de lista de Casas para as fichas).
drop function if exists public.listar_casas_para_ficha();
