import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Auditoria: só entra quem tem a permissão de visualizar a auditoria. */
export default function AuditoriaLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="auditoria.visualizar">{children}</RequerPermissao>;
}
