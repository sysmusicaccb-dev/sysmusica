import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Backup: só entra quem tem a permissão de visualizar o backup (só o Administrador). */
export default function BackupLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="backup.visualizar">{children}</RequerPermissao>;
}
