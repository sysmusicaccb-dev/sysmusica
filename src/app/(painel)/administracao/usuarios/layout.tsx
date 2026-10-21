import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeAdministracao from "@/components/layout/AbasDeAdministracao";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function UsuariosLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="usuarios.visualizar">
      {/* Abas Usuários | Grupos e Permissões (só aparecem para quem tem acesso às duas) */}
      <AbasDeAdministracao />
      {children}
    </RequerPermissao>
  );
}
