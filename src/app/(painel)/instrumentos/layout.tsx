import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function InstrumentosLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="instrumentos.visualizar">{children}</RequerPermissao>;
}
