/**
 * SysMúsica — Configuração do menu e dos breadcrumbs (fonte única).
 *
 * Para incluir uma tela no menu, basta adicionar um item aqui: o menu lateral e os
 * breadcrumbs são gerados a partir desta lista. Só devem entrar telas que EXISTEM.
 * Fase 3: cada item ganhará a permissão necessária para aparecer.
 */
import {
  CalendarDays,
  ClipboardCheck,
  Guitar,
  LayoutDashboard,
  Users,
  type LucideIcon,
} from "lucide-react";

export interface ItemMenu {
  href: string;
  rotulo: string;
  icone: LucideIcon;
}

export interface GrupoMenu {
  titulo: string | null; // null = item solto, sem título de grupo
  itens: ItemMenu[];
}

export const GRUPOS_MENU: GrupoMenu[] = [
  {
    titulo: null,
    itens: [{ href: "/", rotulo: "Dashboard", icone: LayoutDashboard }],
  },
  {
    titulo: "Cadastros",
    itens: [
      { href: "/membros", rotulo: "Membros", icone: Users },
      { href: "/eventos", rotulo: "Eventos", icone: CalendarDays },
      { href: "/instrumentos", rotulo: "Instrumentos e famílias", icone: Guitar },
    ],
  },
  {
    titulo: "Operações",
    itens: [{ href: "/presencas", rotulo: "Presenças", icone: ClipboardCheck }],
  },
];

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
