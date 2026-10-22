"use client";

/** Sysmusica — Abas do módulo de Backup (Backups e Notificações). Cada aba só aparece para quem tem a permissão. */
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { CodigoPermissao } from "@/lib/permissoes";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";

const ABAS: { href: string; rotulo: string; permissao: CodigoPermissao }[] = [
  { href: "/administracao/backup", rotulo: "Backups", permissao: "backup.visualizar" },
  { href: "/administracao/backup/notificacoes", rotulo: "Notificações", permissao: "backup.configurar" },
  { href: "/administracao/backup/destinos", rotulo: "Destinos", permissao: "backup.configurar" },
  { href: "/administracao/backup/agendamento", rotulo: "Agendamento", permissao: "backup.configurar" },
  { href: "/administracao/backup/restauracao", rotulo: "Restauração", permissao: "backup.restaurar" },
];

export default function AbasBackup() {
  const caminho = (usePathname() ?? "").replace(/\/$/, "");
  const { pode } = useSessao();

  return (
    <nav aria-label="Seções do backup" className="mb-5 flex gap-1 border-b border-slate-200">
      {ABAS.filter((aba) => pode(aba.permissao)).map((aba) => {
        const ativa = caminho === aba.href;
        return (
          <Link
            key={aba.href}
            href={aba.href}
            aria-current={ativa ? "page" : undefined}
            className={
              "-mb-px border-b-2 px-4 py-2 text-sm font-medium transition " +
              (ativa
                ? "border-brand-600 text-brand-700"
                : "border-transparent text-slate-600 hover:border-slate-300 hover:text-slate-900")
            }
          >
            {aba.rotulo}
          </Link>
        );
      })}
    </nav>
  );
}
