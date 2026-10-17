"use client";

/**
 * SysMúsica — Protege uma tela inteira: quem não tem a permissão vê "Acesso negado".
 * Usado nos layouts de cada módulo (ex: src/app/(painel)/membros/layout.tsx), de modo que a
 * página nem é carregada para quem não pode vê-la (mesmo digitando a URL na mão).
 */
import type { ReactNode } from "react";
import Link from "next/link";
import EmptyState from "@/components/ui/EmptyState";
import type { CodigoPermissao } from "@/lib/permissoes";
import { useSessao } from "../SessaoProvider";

interface RequerPermissaoProps {
  permissao: CodigoPermissao;
  /** Alternativa: basta ter QUALQUER uma destas permissões. */
  ou?: CodigoPermissao[];
  children: ReactNode;
}

export default function RequerPermissao({ permissao, ou, children }: RequerPermissaoProps) {
  const { pode } = useSessao();

  if (!pode(permissao) && !(ou ?? []).some((alternativa) => pode(alternativa))) {
    return (
      <main className="mx-auto max-w-2xl px-4 py-16">
        <EmptyState
          titulo="Acesso negado"
          descricao="Seu grupo não tem permissão para acessar esta tela."
          acao={
            <Link href="/" className="text-sm font-semibold text-brand-700 hover:underline">
              Voltar ao início
            </Link>
          }
        />
      </main>
    );
  }

  return <>{children}</>;
}
