import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function EventosLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="eventos.visualizar">{children}</RequerPermissao>;
}
