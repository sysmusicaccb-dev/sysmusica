/**
 * SysMúsica — Layout do painel (telas internas).
 *
 * Envolve todas as telas do grupo (painel) com o menu lateral e o topo.
 * Fase 2: é aqui que entrará a verificação de login (usuário não autenticado vai para /login).
 * O nome da pasta entre parênteses é só um agrupamento: não aparece na URL.
 */
import type { ReactNode } from "react";
import AppShell from "@/components/layout/AppShell";

export default function PainelLayout({ children }: { children: ReactNode }) {
  return <AppShell>{children}</AppShell>;
}
