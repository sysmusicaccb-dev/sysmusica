import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";

/** Protege a tela Perfil do Evento: só entra quem pode editar os tipos de evento (os perfis são parte deles). */
export default function PerfilEventoLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="tipoevento.editar">
      {/* Barra de abas de Eventos (Eventos | Tipo do Evento | ... | Perfil do Evento | Configurações) */}
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );
}
