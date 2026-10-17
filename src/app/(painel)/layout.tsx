/**
 * SysMúsica — Layout do painel (telas internas).
 *
 * Envolve todas as telas do grupo (painel) com a guarda de acesso (login obrigatório) e a estrutura
 * visual (menu lateral + topo). O nome da pasta entre parênteses é só um agrupamento: não aparece na URL.
 */
import type { ReactNode } from "react";
import AppShell from "@/components/layout/AppShell";
import GuardaPainel from "@/modules/autenticacao/components/GuardaPainel";

export default function PainelLayout({ children }: { children: ReactNode }) {
  return (
    <GuardaPainel>
      <AppShell>{children}</AppShell>
    </GuardaPainel>
  );
}
