/**
 * SysMúsica — Catálogo de permissões (fonte única no frontend).
 *
 * Cada permissão tem o formato "modulo.acao". O tipo CodigoPermissao faz o TypeScript recusar
 * códigos digitados errado (ex: pode("membros.editr") não compila).
 * Mantenha igual ao catálogo do banco (supabase/migrations/0002_rbac.sql): o teste
 * permissoes.test.ts confere se todo código daqui existe lá.
 */
export const CATALOGO_PERMISSOES = [
  { codigo: "dashboard.visualizar", modulo: "Dashboard", acao: "Visualizar" },
  { codigo: "membros.visualizar", modulo: "Membros", acao: "Visualizar" },
  { codigo: "membros.criar", modulo: "Membros", acao: "Criar" },
  { codigo: "membros.editar", modulo: "Membros", acao: "Editar" },
  { codigo: "membros.excluir", modulo: "Membros", acao: "Excluir" },
  { codigo: "eventos.visualizar", modulo: "Eventos", acao: "Visualizar" },
  { codigo: "eventos.criar", modulo: "Eventos", acao: "Criar" },
  { codigo: "eventos.editar", modulo: "Eventos", acao: "Editar" },
  { codigo: "eventos.excluir", modulo: "Eventos", acao: "Excluir" },
  { codigo: "instrumentos.visualizar", modulo: "Instrumentos", acao: "Visualizar" },
  { codigo: "instrumentos.criar", modulo: "Instrumentos", acao: "Criar" },
  { codigo: "instrumentos.editar", modulo: "Instrumentos", acao: "Editar" },
  { codigo: "instrumentos.excluir", modulo: "Instrumentos", acao: "Excluir" },
  { codigo: "portaria.visualizar", modulo: "Portaria", acao: "Visualizar" },
  { codigo: "portaria.registrar", modulo: "Portaria", acao: "Registrar" },
  { codigo: "portaria.editar", modulo: "Portaria", acao: "Editar" },
  { codigo: "portaria.excluir", modulo: "Portaria", acao: "Excluir" },
] as const;

export type CodigoPermissao = (typeof CATALOGO_PERMISSOES)[number]["codigo"];
