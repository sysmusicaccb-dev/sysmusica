import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** A tela de nomes do menu exige acesso à Administração; a conferência de Master é feita na própria tela e no banco. */
export default function NomesDoMenuLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="usuarios.visualizar">{children}</RequerPermissao>;
}
