/**
 * SysMúsica — Cartão "Atalhos" do dashboard.
 * Cada atalho leva a uma tela real, onde fica o formulário correspondente.
 * Fase 3: os atalhos passarão a respeitar as permissões do usuário.
 */
import Link from "next/link";
import { CalendarPlus, ClipboardCheck, UserPlus, type LucideIcon } from "lucide-react";
import Card from "@/components/ui/Card";

const ATALHOS: { href: string; rotulo: string; descricao: string; icone: LucideIcon }[] = [
  { href: "/membros", rotulo: "Cadastrar membro", descricao: "Novo membro, cargo e instrumento", icone: UserPlus },
  { href: "/eventos", rotulo: "Cadastrar evento", descricao: "Ensaio, culto ou outro evento", icone: CalendarPlus },
  { href: "/portaria", rotulo: "Portaria", descricao: "Registrar a entrada dos membros no evento", icone: ClipboardCheck },
];

export default function AtalhosRapidos() {
  return (
    <Card titulo="Atalhos" descricao="Ações mais usadas.">
      <ul className="space-y-2">
        {ATALHOS.map(({ href, rotulo, descricao, icone: Icone }) => (
          <li key={href}>
            <Link
              href={href}
              className="flex items-center gap-3 rounded-xl border border-slate-200 p-3 transition hover:border-brand-200 hover:bg-brand-50/50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
            >
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-700">
                <Icone className="h-5 w-5" aria-hidden="true" />
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-medium text-slate-900">{rotulo}</span>
                <span className="block truncate text-xs text-slate-500">{descricao}</span>
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </Card>
  );
}
