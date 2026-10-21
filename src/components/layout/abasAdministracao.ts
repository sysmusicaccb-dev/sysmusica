/**
 * SysMúsica — Abas da Administração de acesso (regra pura): Usuários | Grupos e Permissões.
 * Cada aba é uma tela que já existe (mesma rota e mesma permissão); aqui só se decide QUAIS abas a pessoa vê.
 * As abas existem para quem tem a permissão de Usuários e acesso também a Grupos: quem só tem Grupos
 * continua com o item "Grupos e Permissões" no menu (ver ocultoSe em navegacao.ts) e não vê barra de abas.
 */
import type { CodigoPermissao } from "@/lib/permissoes";

export interface AbaAdministracao {
  href: string;
  rotulo: string;
}

export function abasDeAdministracao(pode: (permissao: CodigoPermissao) => boolean): AbaAdministracao[] {
  if (!pode("usuarios.visualizar")) return [];

  const abas: AbaAdministracao[] = [{ href: "/administracao/usuarios", rotulo: "Usuários" }];
  if (pode("grupos.visualizar")) abas.push({ href: "/administracao/grupos", rotulo: "Grupos e Permissões" });

  // Uma aba só não precisa de barra
  return abas.length > 1 ? abas : [];
}
