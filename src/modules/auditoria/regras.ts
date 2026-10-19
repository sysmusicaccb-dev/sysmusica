/**
 * SysMúsica — Regras puras da Auditoria (sem banco): nomes legíveis, "antes e depois" e período dos filtros.
 * Testadas em regras.test.ts.
 */
import { formatarDataHora } from "@/lib/datas";
import type { LinhaAuditoria, MudancaCampo } from "./tipos";

const ROTULO_ACAO: Record<string, string> = {
  registro_criado: "Cadastrou",
  registro_alterado: "Alterou",
  registro_excluido: "Excluiu",
  login: "Entrou no sistema",
  portaria_criada: "Criou portaria",
  portaria_aprovada: "Aprovou portaria",
  portaria_rejeitada: "Rejeitou portaria",
  portaria_excluida: "Excluiu portaria",
  organizacao_criada: "Cadastrou na organização",
  organizacao_alterada: "Alterou na organização",
  organizacao_excluida: "Excluiu da organização",
  comum_transferida: "Transferiu comum de setor",
  evento_comum_alterada: "Mudou a comum do evento",
  visitante_cadastrado: "Cadastrou visitante",
  foto_definida: "Definiu fotografia",
  foto_removida: "Removeu fotografia",
  vinculos_definidos: "Definiu vínculos do usuário",
  usuario_grupos_definidos: "Definiu grupos do usuário",
  abrangencia_definida: "Definiu abrangência (cidades)",
  relatorio_impresso: "Imprimiu relatório",
  relatorio_exportado: "Exportou relatório",
  auditoria_impressa: "Imprimiu a auditoria",
  auditoria_exportada: "Exportou a auditoria",
  backup_criado: "Fez um backup",
  backup_restaurado: "Restaurou dados de um backup",
  backup_excluido: "Excluiu um backup",
  backup_baixado: "Baixou um backup",
  backup_verificado: "Verificou um backup",
  backup_aviso_testado: "Testou os avisos do backup",
  backup_destino_alterado: "Alterou o destino do backup",
  backup_destino_testado: "Testou o destino do backup",
  backup_copiado_destino: "Copiou o backup para o servidor local",
  backup_configuracao_alterada: "Alterou a configuração do backup",
};

const ROTULO_ENTIDADE: Record<string, string> = {
  membro: "Membro",
  evento: "Evento",
  presenca: "Presença",
  instrumento: "Instrumento",
  cargo: "Cargo",
  familia: "Família",
  finalidade: "Finalidade de evento",
  usuario: "Usuário",
  grupo: "Grupo",
  grupo_permissao: "Permissão do grupo",
  vinculo: "Vínculo do usuário",
  estado: "Estado",
  regiao: "Região",
  setor: "Setor",
  comum: "Comum",
  organizacao: "Organização",
  portaria: "Portaria",
  relatorio: "Relatório",
  backup: "Backup",
};

const ROTULO_CAMPO: Record<string, string> = {
  nome: "Nome",
  congregacao: "Congregação",
  cargo_id: "Cargo",
  data_nascimento: "Data de nascimento",
  instrumento_id: "Instrumento",
  status: "Situação",
  cidade: "Cidade",
  bairro: "Bairro",
  comum_id: "Comum",
  origem_comum_id: "Comum de origem",
  visitante: "Visitante",
  ativo: "Ativo",
  tipo: "Tipo",
  data_evento: "Data do evento",
  local: "Local",
  finalidade_id: "Finalidade",
  excluido_em: "Excluído em",
  foto_path: "Fotografia",
  email: "E-mail",
  grupo_id: "Grupo",
  setor_id: "Setor",
  regiao_id: "Região",
  estado_id: "Estado",
  descricao: "Descrição",
  hora_entrada: "Hora de entrada",
  hora_saida: "Hora de saída",
  portaria_id: "Portaria",
  membro_id: "Membro",
  evento_id: "Evento",
  usuario_id: "Usuário",
  origem: "Origem do registro",
  familia_id: "Família",
  permite_instrumento: "Permite instrumento",
  permissao_codigo: "Permissão",
  nivel: "Nível",
  alvo_id: "Alvo do vínculo",
  cpf: "CPF",
  cpf_mascarado: "CPF (parcial)",
  qr_secret: "QR Code",
};

/** "registro_criado" -> "Registro criado" (para códigos que não têm texto próprio). */
export function humanizar(codigo: string): string {
  const texto = codigo.replace(/_/g, " ").trim();
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

export function rotuloAcao(acao: string): string {
  return ROTULO_ACAO[acao] ?? humanizar(acao);
}

export function rotuloEntidade(entidade: string): string {
  return ROTULO_ENTIDADE[entidade] ?? humanizar(entidade);
}

export function rotuloCampo(campo: string): string {
  return ROTULO_CAMPO[campo] ?? humanizar(campo);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATA_HORA_ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;
const DATA_ISO = /^\d{4}-\d{2}-\d{2}$/;

/** Valor de um campo em texto legível (sim/não, datas em português, identificadores abreviados). */
export function formatarValor(valor: unknown): string {
  if (valor === null || valor === undefined || valor === "") return "—";
  if (typeof valor === "boolean") return valor ? "Sim" : "Não";
  if (typeof valor === "number") return String(valor);
  if (typeof valor === "string") {
    if (UUID.test(valor)) return `${valor.slice(0, 8)}…`;
    if (DATA_HORA_ISO.test(valor)) return formatarDataHora(valor);
    if (DATA_ISO.test(valor)) {
      const [ano, mes, dia] = valor.split("-");
      return `${dia}/${mes}/${ano}`;
    }
    return valor;
  }
  const json = JSON.stringify(valor);
  return json.length > 120 ? `${json.slice(0, 117)}...` : json;
}

function comoObjeto(valor: unknown): Record<string, unknown> | null {
  return valor !== null && typeof valor === "object" && !Array.isArray(valor)
    ? (valor as Record<string, unknown>)
    : null;
}

/**
 * Transforma os detalhes de um registro em linhas legíveis:
 *  - alteração: campo, valor antes e valor depois;
 *  - cadastro: os dados gravados; exclusão: os dados que existiam;
 *  - ações do sistema (portaria, organização...): os dados informados.
 */
export function descreverDetalhes(detalhes: Record<string, unknown> | null): MudancaCampo[] {
  if (!detalhes) return [];

  const mudancas = comoObjeto(detalhes.mudancas);
  if (mudancas) {
    return Object.entries(mudancas).map(([campo, valor]) => {
      const par = comoObjeto(valor);
      if (par && ("de" in par || "para" in par)) {
        return { campo: rotuloCampo(campo), de: formatarValor(par.de), para: formatarValor(par.para) };
      }
      return { campo: rotuloCampo(campo), de: null, para: formatarValor(valor) };
    });
  }

  const depois = comoObjeto(detalhes.depois);
  if (depois) {
    return Object.entries(depois)
      .filter(([, valor]) => valor !== null && valor !== undefined)
      .map(([campo, valor]) => ({ campo: rotuloCampo(campo), de: null, para: formatarValor(valor) }));
  }

  const antes = comoObjeto(detalhes.antes);
  if (antes) {
    return Object.entries(antes)
      .filter(([, valor]) => valor !== null && valor !== undefined)
      .map(([campo, valor]) => ({ campo: rotuloCampo(campo), de: formatarValor(valor), para: null }));
  }

  return Object.entries(detalhes)
    .filter(([campo, valor]) => campo !== "rotulo" && valor !== null && valor !== undefined)
    .map(([campo, valor]) => ({ campo: rotuloCampo(campo), de: null, para: formatarValor(valor) }));
}

/** Resumo em uma linha (impressão e CSV): "Nome: Ana → Ana Maria; Situação: Ativo → Inativo". */
export function resumoAlteracoes(detalhes: Record<string, unknown> | null): string {
  return descreverDetalhes(detalhes)
    .map((item) =>
      item.de !== null && item.para !== null
        ? `${item.campo}: ${item.de} → ${item.para}`
        : `${item.campo}: ${item.para ?? item.de ?? "—"}`
    )
    .join("; ");
}

/** "Membro · Maria da Silva" (o nome vem do próprio registro, quando existe). */
export function rotuloDoItem(linha: Pick<LinhaAuditoria, "entidade" | "detalhes">): string {
  const rotulo = linha.detalhes?.rotulo;
  const nome = typeof rotulo === "string" && rotulo.trim() !== "" ? ` · ${rotulo}` : "";
  return `${rotuloEntidade(linha.entidade)}${nome}`;
}

function proximoDia(dia: string): string {
  const data = new Date(`${dia}T12:00:00Z`);
  data.setUTCDate(data.getUTCDate() + 1);
  return `${data.toISOString().slice(0, 10)}T00:00:00-03:00`;
}

/**
 * Período do filtro: do início do primeiro dia até o fim do último dia, no horário de Salvador (-03:00,
 * sem horário de verão). Data vazia ou inválida = sem limite.
 */
export function intervaloDoFiltro(inicio: string, fim: string): { inicio: string | null; fim: string | null } {
  return {
    inicio: DATA_ISO.test(inicio) ? `${inicio}T00:00:00-03:00` : null,
    fim: DATA_ISO.test(fim) ? proximoDia(fim) : null,
  };
}
