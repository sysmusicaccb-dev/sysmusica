import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Relatórios: só entra quem tem a permissão de relatórios. */
export default function RelatoriosLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="relatorios.visualizar">{children}</RequerPermissao>;
}
