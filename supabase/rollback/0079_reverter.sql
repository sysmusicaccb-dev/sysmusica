-- Desfaz a 0079 (Perfil do Evento). Os tipos de evento continuam funcionando pelo modelo (LOCAL/REGIONAL).
drop function if exists public.listar_perfis_evento();
drop function if exists public.perfis_dos_tipos_evento();
drop function if exists public.salvar_perfil_evento(uuid, jsonb);
drop function if exists public.duplicar_perfil_evento(uuid);
drop function if exists public.excluir_perfil_evento(uuid);
drop function if exists public.vincular_perfil_tipo_evento(uuid, uuid);
alter table public.tipos_evento drop column if exists perfil_id;
drop table if exists public.perfis_evento;
