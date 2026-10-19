import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela do Painel ao vivo: só entra quem tem a permissão de visualizar o painel. */
export default function PainelAoVivoLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="painel.visualizar">{children}</RequerPermissao>;
}
