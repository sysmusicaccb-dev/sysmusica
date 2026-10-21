import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela: só entra quem tem a permissão de visualizar os cadastros pendentes. */
export default function CadastrosPendentesLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="cadastros.visualizar">{children}</RequerPermissao>;
}
