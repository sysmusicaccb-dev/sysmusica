/** SysMúsica — Tipos do módulo de Backup que o navegador e o servidor compartilham. */
import type { ResultadoCanal, ResultadoVerificacao, SituacaoVerificacao, TipoBackup } from "./regras";

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
  verificacao: SituacaoVerificacao; // pendente = ainda não verificado
  verificado_em: string | null;
  verificado_por_nome: string | null; // nulo com verificado_em preenchido = verificado pelo sistema
  verificacao_detalhe: string | null;
}

export interface RespostaFazerBackup {
  backup: RegistroBackup;
  avisos: ResultadoCanal[];
  verificacao: ResultadoVerificacao; // resultado da verificação automática
  refeito: boolean; // true = a primeira cópia falhou na verificação e foi refeita
}
