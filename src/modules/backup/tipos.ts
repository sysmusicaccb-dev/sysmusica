/** SysMúsica — Tipos do módulo de Backup que o navegador e o servidor compartilham. */
import type { ResultadoCanal, TipoBackup } from "./regras";

/** Uma linha da lista de backups. */
export interface RegistroBackup {
  id: string;
  criado_em: string;
  tipo: TipoBackup;
  situacao: "ok" | "falhou";
  tamanho_bytes: number | null;
  sha256: string | null;
  contagens: Record<string, number> | null;
  criado_por: string | null;
  criado_por_nome: string | null; // nulo = ação do sistema
  observacao: string | null;
  erro: string | null;
  destinos: Record<string, boolean> | null;
}

export interface RespostaFazerBackup {
  backup: RegistroBackup;
  avisos: ResultadoCanal[];
}
