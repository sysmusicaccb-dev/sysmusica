/**
 * SysMúsica — Tipos da entrada na Portaria com "Vai tocar?" e da entrada SEM cadastro (migração 0028).
 * Os campos são os devolvidos pelas funções do banco (info_entrada, opcoes_entrada, buscar_localidades ...).
 */

/** Blocos do painel ao vivo (mesmos da tabela linhas_painel). */
export type BlocoEntrada = "MINISTERIO" | "MUSICOS" | "ORGANISTAS";

/** Como a pessoa é contada e se a Portaria precisa perguntar "Vai tocar?" (resposta de info_entrada). */
export interface InfoEntrada {
  linha_codigo: string;
  linha_rotulo: string;
  bloco: BlocoEntrada;
  pergunta_toca: boolean;
  instrumento_id: string | null; // instrumento do cadastro
  instrumento: string | null;
}

/** Uma linha do painel que pode ser escolhida na entrada sem cadastro. */
export interface LinhaEntrada {
  codigo: string;
  bloco: BlocoEntrada;
  rotulo: string;
  pergunta_toca: boolean;
  toca_sempre: boolean;
  instrumento: "NENHUM" | "ORGAO" | "LIVRE";
}

export interface InstrumentoEntrada {
  id: string;
  nome: string;
  familia: string;
}

export interface OpcoesEntrada {
  linhas: LinhaEntrada[];
  instrumentos: InstrumentoEntrada[];
}

/** Resultado da busca de localidade (casa de oração + caminho na organização). */
export interface LocalidadeBusca {
  comum_id: string;
  nome: string;
  caminho: string;
}

/** Entrada sem cadastro já registrada na portaria. */
export interface EntradaAvulsa {
  id: string;
  linha_rotulo: string;
  bloco: BlocoEntrada;
  toca: boolean | null;
  instrumento: string | null;
  origem: string | null;
  hora_entrada: string;
  total: number;
}

/** O que a Portaria respondeu na conferência de um membro. */
export interface EscolhaToca {
  toca: boolean | null; // null = ainda não respondeu
  instrumentoId: string; // "" = usar o instrumento do cadastro
}
