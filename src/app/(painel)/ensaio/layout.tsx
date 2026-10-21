import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Entra quem pode ver os Dados do Ensaio ou quem pode preenchê-los. */
export default function EnsaioLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="ensaio.visualizar" ou={["ensaio.registrar"]}>
      {children}
    </RequerPermissao>
  );
}
