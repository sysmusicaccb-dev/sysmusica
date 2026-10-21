import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function HinosLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="hinos.visualizar">{children}</RequerPermissao>;
}
