import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function EventosLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="eventos.visualizar">
      {/* Abas Eventos | Gestão de portarias | Portaria (só aparecem para quem tem acesso a mais de uma) */}
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );
}
