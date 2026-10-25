delete from public.grupo_permissoes gp using public.grupos g
 where g.id = gp.grupo_id and g.nome = 'Administrador Regional'
   and gp.permissao_codigo in ('cadastros.visualizar', 'cadastros.aprovar');
