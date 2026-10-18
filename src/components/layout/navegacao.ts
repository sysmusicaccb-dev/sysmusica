/**
 * SysMúsica — Configuração do menu e dos breadcrumbs (fonte única).
 *
 * Para incluir uma tela no menu, basta adicionar um item aqui: o menu lateral e os
 * breadcrumbs são gerados a partir desta lista. Só devem entrar telas que EXISTEM.
 * Cada item informa a permissão necessária: quem não a tem não vê o item no menu
 * (e a própria tela também é protegida por RequerPermissao).
 */
import {
  CalendarDays,
  Building2,
  Camera,
  ScrollText,
  ClipboardList,
  DoorOpen,
  Guitar,
  KeyRound,
  LayoutDashboard,
  ShieldCheck,
  Users,
  type LucideIcon,
} from "lucide-react";
import type { CodigoPermissao } from "@/lib/permissoes";

export interface ItemMenu {
  href: string;
  rotulo: string;
  icone: LucideIcon;
  permissao: CodigoPermissao; // quem não tem esta permissão não vê o item
  qualquer?: CodigoPermissao[]; // ...a não ser que tenha QUALQUER uma destas
}

export interface GrupoMenu {
  titulo: string | null; // null = item solto, sem título de grupo
  itens: ItemMenu[];
}

export const GRUPOS_MENU: GrupoMenu[] = [
  {
    titulo: null,
    itens: [
      { href: "/", rotulo: "Dashboard", icone: LayoutDashboard, permissao: "dashboard.visualizar" },
    ],
  },
  {
    titulo: "Cadastros",
    itens: [
      { href: "/membros", rotulo: "Membros", icone: Users, permissao: "membros.visualizar" },
      { href: "/eventos", rotulo: "Eventos", icone: CalendarDays, permissao: "eventos.visualizar" },
      {
        href: "/instrumentos",
        rotulo: "Instrumentos e famílias",
        icone: Guitar,
        permissao: "instrumentos.visualizar",
      },
    ],
  },
  {
    titulo: "Operações",
    itens: [
      {
        href: "/portarias",
        rotulo: "Gestão de portarias",
        icone: ClipboardList,
        permissao: "portarias.visualizar",
        qualquer: ["portarias.criar", "portarias.aprovar"],
      },
      { href: "/portaria", rotulo: "Portaria", icone: DoorOpen, permissao: "portaria.visualizar" },
      { href: "/fotografias", rotulo: "Fotografias", icone: Camera, permissao: "membros.foto" },
    ],
  },
  {
    titulo: "Administração",
    itens: [
      {
        href: "/administracao/organizacao",
        rotulo: "Organização",
        icone: Building2,
        permissao: "organizacao.visualizar",
      },
      {
        href: "/administracao/auditoria",
        rotulo: "Auditoria",
        icone: ScrollText,
        permissao: "auditoria.visualizar",
      },
      {
        href: "/administracao/usuarios",
        rotulo: "Usuários",
        icone: KeyRound,
        permissao: "usuarios.visualizar",
      },
      {
        href: "/administracao/grupos",
        rotulo: "Grupos e permissões",
        icone: ShieldCheck,
        permissao: "grupos.visualizar",
      },
    ],
  },
];

/** O usuário pode ver o item? (a permissão principal ou qualquer uma das alternativas) */
function itemPermitido(item: ItemMenu, pode: (permissao: CodigoPermissao) => boolean): boolean {
  return pode(item.permissao) || (item.qualquer ?? []).some((permissao) => pode(permissao));
}

/** Filtra o menu pelas permissões do usuário, removendo também os grupos que ficarem vazios. */
export function filtrarMenu(
  grupos: GrupoMenu[],
  pode: (permissao: CodigoPermissao) => boolean
): GrupoMenu[] {
  return grupos
    .map((grupo) => ({ ...grupo, itens: grupo.itens.filter((item) => itemPermitido(item, pode)) }))
    .filter((grupo) => grupo.itens.length > 0);
}

/** Primeira tela (fora do dashboard) que o usuário pode acessar; null se não puder nenhuma. */
export function primeiraRotaPermitida(pode: (permissao: CodigoPermissao) => boolean): string | null {
  for (const grupo of GRUPOS_MENU) {
    for (const item of grupo.itens) {
      if (item.href !== "/" && itemPermitido(item, pode)) return item.href;
    }
  }
  return null;
}

/** O item está ativo na rota atual? A raiz "/" só é ativa exatamente em "/". */
export function itemAtivo(href: string, caminho: string): boolean {
  if (href === "/") return caminho === "/";
  return caminho === href || caminho.startsWith(`${href}/`);
}

export interface Migalha {
  rotulo: string;
  href?: string; // sem href = apenas texto (grupo ou página atual)
}

/** Monta o caminho exibido nos breadcrumbs: Início > Grupo > Página. */
export function montarMigalhas(caminho: string): Migalha[] {
  for (const grupo of GRUPOS_MENU) {
    for (const item of grupo.itens) {
      if (!itemAtivo(item.href, caminho)) continue;

      // Na raiz, o próprio Dashboard é o único nível
      if (item.href === "/") return [{ rotulo: item.rotulo }];

      const migalhas: Migalha[] = [{ rotulo: "Início", href: "/" }];
      if (grupo.titulo) migalhas.push({ rotulo: grupo.titulo });
      migalhas.push({ rotulo: item.rotulo });
      return migalhas;
    }
  }
  // Rota fora do menu: mostra só o caminho de volta ao início
  return [{ rotulo: "Início", href: "/" }];
}

/**
 * Remove dos breadcrumbs o link "Início" para quem não acessa o dashboard (ex: grupo Portaria):
 * para essa pessoa o menu mostra somente o que o grupo permite, e nada além disso.
 */
export function migalhasVisiveis(
  migalhas: Migalha[],
  pode: (permissao: CodigoPermissao) => boolean
): Migalha[] {
  return migalhas.filter((migalha) => migalha.href !== "/" || pode("dashboard.visualizar"));
}
