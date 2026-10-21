import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function PortariaLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="portaria.visualizar">
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );
}
