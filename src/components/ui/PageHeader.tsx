/**
 * Sysmusica — Cabeçalho de página (UI base): título, descrição e ações (ex: botão "Novo ...").
 */
import type { ReactNode } from "react";
import {
  Activity,
  Building2,
  CalendarDays,
  ClipboardList,
  CreditCard,
  Database,
  DoorOpen,
  FileSearch,
  FileText,
  Menu,
  ShieldCheck,
  Users,
  type LucideIcon,
} from "lucide-react";

/** Ícone de cada tela, pelo título do cabeçalho (assim as telas não precisam informar). O Dashboard fica sem ícone. */
const ICONES_POR_TITULO: Record<string, LucideIcon> = {
  Eventos: CalendarDays,
  Portarias: FileText,
  Portaria: DoorOpen,
  "Registros da portaria": ClipboardList,
  "Cadastros Pendentes": FileText,
  "Cartões a Vencer": CreditCard,
  "Painel ao Vivo": Activity,
  Auditoria: FileSearch,
  Organização: Building2,
  Backup: Database,
  Usuários: Users,
  "Grupos e Permissões": ShieldCheck,
  "Nomes do Menu": Menu,
};

/** Ícone dentro do quadradinho azul-claro do cabeçalho (também usado pelas telas com cabeçalho próprio). */
export function IconeDeCabecalho({ icone: Icone }: { icone: LucideIcon }) {
  return (
    <span
      aria-hidden="true"
      className="inline-flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-brand-100 text-brand-600"
    >
      <Icone className="h-7 w-7" />
    </span>
  );
}

interface PageHeaderProps {
  titulo: string;
  descricao?: string;
  acoes?: ReactNode;
  /** Ícone do cabeçalho; sem ele vale o da tabela acima (pelo título). */
  icone?: LucideIcon;
}

export default function PageHeader({ titulo, descricao, acoes, icone }: PageHeaderProps) {
  const Icone = icone ?? ICONES_POR_TITULO[titulo];

  // Cabeçalho em cartão, com o ícone (padrão do desenho)
  if (Icone) {
    return (
      <header className="mb-5 flex flex-col gap-4 rounded-2xl border border-slate-200 bg-brand-50/60 px-5 py-4 shadow-sm sm:flex-row sm:items-center sm:justify-between">
        <div className="flex min-w-0 items-center gap-4">
          <IconeDeCabecalho icone={Icone} />
          <div className="min-w-0">
            <h1 className="text-2xl font-bold tracking-tight text-slate-900">{titulo}</h1>
            {descricao && <p className="mt-0.5 text-sm text-slate-600">{descricao}</p>}
          </div>
        </div>
        {acoes && <div className="flex shrink-0 flex-wrap items-center gap-2">{acoes}</div>}
      </header>
    );
  }

  // Sem ícone (Dashboard): título e descrição soltos
  return (
    <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">{titulo}</h1>
        {descricao && <p className="mt-1 text-sm text-slate-600">{descricao}</p>}
      </div>
      {acoes && <div className="flex shrink-0 items-center gap-2">{acoes}</div>}
    </header>
  );
}
