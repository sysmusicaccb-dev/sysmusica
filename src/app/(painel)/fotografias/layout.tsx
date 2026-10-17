import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de fotografias: só quem tem a permissão de fotografia dos membros entra. */
export default function FotografiasLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="membros.foto">{children}</RequerPermissao>;
}
