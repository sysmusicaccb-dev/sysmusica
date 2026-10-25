import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Fichas Musicais: só entra quem tem a permissão de visualizar. */
export default function FichasLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="fichas.visualizar">{children}</RequerPermissao>;
}
