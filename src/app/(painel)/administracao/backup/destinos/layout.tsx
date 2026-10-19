import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Destinos do backup: só entra quem tem a permissão de configurar o backup (só o Administrador). */
export default function NotificacoesBackupLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="backup.configurar">{children}</RequerPermissao>;
}
