/**
 * SysMúsica — Configuração do menu e dos breadcrumbs (fonte única).
 *
 * Para incluir uma tela no menu, basta adicionar um item aqui: o menu lateral e os
 * breadcrumbs são gerados a partir desta lista. Só devem entrar telas que EXISTEM.
 * Cada item informa a permissão necessária: quem não a tem não vê o item no menu
 * (e a própria tela também é protegida por RequerPermissao).
 */
import {
  Activity,
  CalendarDays,
  Building2,
  DatabaseBackup,
  FileText,
  ScrollText,
  ClipboardCheck,
  ClipboardList,
  DoorOpen,
  Guitar,
  Inbox,
  KeyRound,
  LayoutDashboard,
  Music2,
  ShieldCheck,
  Tag,
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
  ocultoSe?: CodigoPermissao; // o item SOME do menu para quem tem esta permissão (acessa por aba de outro item)
  tambemAtivoEm?: string[]; // rotas que também deixam este item marcado no menu (ex.: abas de Eventos)
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
      { href: "/membros", rotulo: "Músicos e Organistas", icone: Users, permissao: "membros.visualizar" },
      {
        href: "/eventos",
        rotulo: "Eventos",
        icone: CalendarDays,
        permissao: "eventos.visualizar",
        // Tipo do Evento, Gestão de portarias e Portaria são ABAS dentro de Eventos: o item continua marcado nessas telas
        tambemAtivoEm: ["/tipos-evento", "/portarias", "/portaria"],
      },
      {
        href: "/instrumentos",
        rotulo: "Instrumentos e Famílias",
        icone: Guitar,
        permissao: "instrumentos.visualizar",
      },
      {
        href: "/tipos-evento",
        rotulo: "Tipo do Evento",
        icone: Tag,
        permissao: "tipoevento.visualizar",
        ocultoSe: "eventos.visualizar", // quem vê Eventos acessa por aba; quem só tem Tipo do Evento continua vendo o item
      },
      { href: "/hinos", rotulo: "Hinos", icone: Music2, permissao: "hinos.visualizar" },
      // Fila de cadastros enviados pelo link público (/cadastro); o número pendente aparece no menu (Sidebar)
      { href: "/cadastros-pendentes", rotulo: "Cadastros Pendentes", icone: Inbox, permissao: "cadastros.visualizar" },
    ],
  },
  {
    titulo: "Operações",
    itens: [
      {
        href: "/portarias",
        rotulo: "Gestão de Portarias",
        icone: ClipboardList,
        permissao: "portarias.visualizar",
        qualquer: ["portarias.criar", "portarias.aprovar"],
        ocultoSe: "eventos.visualizar", // quem vê Eventos acessa por aba; os demais mantêm o item
      },
      {
        href: "/portaria",
        rotulo: "Portaria",
        icone: DoorOpen,
        permissao: "portaria.visualizar",
        ocultoSe: "eventos.visualizar", // quem vê Eventos acessa por aba; quem só tem Portaria continua vendo só este item
      },
      {
        href: "/ensaio",
        rotulo: "Dados do Ensaio",
        icone: ClipboardCheck,
        permissao: "ensaio.visualizar",
        qualquer: ["ensaio.registrar"], // quem só preenche (sem ver) também acessa
      },
      { href: "/painel-ao-vivo", rotulo: "Painel ao Vivo", icone: Activity, permissao: "painel.visualizar" },
      { href: "/relatorios", rotulo: "Relatórios", icone: FileText, permissao: "relatorios.visualizar" },
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
        href: "/administracao/backup",
        rotulo: "Backup",
        icone: DatabaseBackup,
        permissao: "backup.visualizar",
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
        rotulo: "Grupos e Permissões",
        icone: ShieldCheck,
        permissao: "grupos.visualizar",
      },
    ],
  },
];

/** O usuário pode ver o item? (a permissão principal ou qualquer uma das alternativas) */
function itemPermitido(item: ItemMenu, pode: (permissao: CodigoPermissao) => boolean): boolean {
  // Itens que viraram aba de outro item somem do menu de quem já tem esse outro item
  if (item.ocultoSe && pode(item.ocultoSe)) return false;
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

/** O item do menu está ativo? Vale a rota dele e as rotas das suas abas (ex.: Eventos > Portaria). */
export function itemMenuAtivo(item: ItemMenu, caminho: string): boolean {
  return itemAtivo(item.href, caminho) || (item.tambemAtivoEm ?? []).some((rota) => itemAtivo(rota, caminho));
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
