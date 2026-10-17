import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/**
 * Protege a tela "Registros da portaria" (histórico, editar, excluir e lançamento em lote):
 * só entra quem pode corrigir registros. Quem apenas atende na portaria usa a tela de atendimento.
 */
export default function RegistrosPortariaLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="portaria.editar" ou={["portaria.excluir"]}>
      {children}
    </RequerPermissao>
  );
}
