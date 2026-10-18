import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Organização: só entra quem pode visualizar estados, regiões, setores e comuns. */
export default function OrganizacaoLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="organizacao.visualizar">{children}</RequerPermissao>;
}
