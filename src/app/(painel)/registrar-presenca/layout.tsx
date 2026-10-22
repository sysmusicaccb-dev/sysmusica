import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela Registrar Presença: só entra quem tem a permissão de ver a Portaria. */
export default function RegistrarPresencaLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="portaria.visualizar">{children}</RequerPermissao>;
}
