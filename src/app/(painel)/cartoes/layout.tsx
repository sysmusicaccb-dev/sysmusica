import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Cartões a Vencer: só entra quem tem a permissão de visualizar. */
export default function CartoesLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="cartoes.visualizar">{children}</RequerPermissao>;
}
