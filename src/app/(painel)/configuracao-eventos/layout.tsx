import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";

/** Eventos > Configurações: só entra quem tem a permissão de configurar eventos. */
export default function ConfiguracaoEventosLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="eventos.configurar">
      {/* Barra de abas de Eventos (Eventos | Tipo do Evento | Gestão de Portarias | Configurações) */}
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );
}
