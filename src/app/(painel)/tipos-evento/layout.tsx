import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function TiposEventoLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="tipoevento.visualizar">
      {/* Barra de abas de Eventos (Eventos | Tipo do Evento | ...): só aparece para quem vê Eventos */}
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );
}
