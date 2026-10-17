import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a Gestão de portarias: quem cria, aprova ou visualiza portarias entra. */
export default function PortariasLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="portarias.visualizar" ou={["portarias.criar", "portarias.aprovar"]}>
      {children}
    </RequerPermissao>
  );
}
