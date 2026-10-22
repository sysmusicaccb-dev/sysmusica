/**
 * Sysmusica — Regras puras do "Cadastro Musical" (sem banco, sem tela). Testadas em cadastroMusical.test.ts.
 *
 * O cadastro tem duas partes:
 *  - dados que já ficavam em "membros" (nome, casa de oração, cargo, instrumento, categoria, cidade, bairro, CPF...);
 *  - dados pessoais novos (estado civil, sexo, telefone, endereço, cartão de identificação...), guardados na
 *    tabela PROTEGIDA membros_cadastro e lidos/gravados só pelas funções do banco obter_cadastro_musical e
 *    salvar_cadastro_musical (migração 0038). A tela nunca lê essa tabela diretamente.
 *
 * Para mudar quais cargos aparecem no cadastro: lista CARGOS_DO_CADASTRO abaixo.
 * Para mudar quais cargos exigem o cartão de identificação: coluna cargos.exige_cartao (banco);
 * enquanto a coluna não existir, vale a lista CARGOS_COM_CARTAO_PADRAO.
 * Para mudar quais cargos só aceitam o instrumento Órgão: coluna cargos.somente_orgao (banco, migração 0040);
 * enquanto a coluna não existir, vale a lista CARGOS_SOMENTE_ORGAO_PADRAO.
 *
 * Migração 0040: estado civil com os rótulos "Casado (a)"..., campo Batizado (Sim/Não), documento de identificação
 * (frente e verso, em armazenamento privado) e consulta de endereço pelo CEP (ViaCEP).
 */

// Estes textos são os mesmos aceitos pelo banco (migração 0040): mudou aqui, muda lá.
export const ESTADOS_CIVIS = ["Casado (a)", "Solteiro (a)", "Viúvo (a)"] as const;
export const SEXOS = ["Masculino", "Feminino"] as const;
export const UFS = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
  "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
] as const;

/** Sim/Não dos campos de múltipla escolha ("" = ainda não respondido). */
export type SimNao = "" | "sim" | "nao";

/** Os dados do formulário (todos texto, para ligar direto nos campos da tela). */
export interface CadastroMusical {
  estado_civil: string;
  sexo: string;
  batizado: SimNao;
  data_batismo: string; // AAAA-MM-DD (só quando batizado = "sim")
  selado: SimNao;
  ddd: string; // 2 dígitos
  telefone: string; // 8 ou 9 dígitos
  tem_whatsapp: SimNao;
  whatsapp: string; // DDD + número (10 ou 11 dígitos)
  email: string;
  cep: string; // 8 dígitos
  endereco: string;
  numero: string;
  complemento: string;
  uf: string;
  cartao_numero: string;
  cartao_emissao: string; // AAAA-MM-DD
  cartao_validade: string; // AAAA-MM-DD
  apresentado_em: string; // AAAA-MM-DD
  apresentado_por: string;
  observacao: string;
  documento_frente_path: string; // caminho do arquivo no armazenamento privado (documentos-membros)
  documento_verso_path: string;
}

export const CADASTRO_VAZIO: CadastroMusical = {
  estado_civil: "",
  sexo: "",
  batizado: "",
  data_batismo: "",
  selado: "",
  ddd: "",
  telefone: "",
  tem_whatsapp: "",
  whatsapp: "",
  email: "",
  cep: "",
  endereco: "",
  numero: "",
  complemento: "",
  uf: "",
  cartao_numero: "",
  cartao_emissao: "",
  cartao_validade: "",
  apresentado_em: "",
  apresentado_por: "",
  observacao: "",
  documento_frente_path: "",
  documento_verso_path: "",
};

// ---------- Cargos ----------

/** O mínimo que precisamos de um cargo (o tipo Cargo do projeto atende a isto). */
export interface CargoCadastro {
  id: string;
  nome: string;
  exige_cartao?: boolean | null;
  somente_orgao?: boolean | null;
}

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

/**
 * Cargos que têm Cadastro Musical (início do nome, sem acento). Ancião, Diácono, Cooperadores e Secretário da
 * Música não têm mais cadastro: só entram nas contagens. "Candidato(a)" ficou de fora até a CCB confirmar.
 */
export const CARGOS_DO_CADASTRO = [
  "encarregado regional",
  "encarregado local",
  "examinadora",
  "instrutor",
  "musico",
  "organista",
] as const;

/** Cargos que exigem o cartão de identificação enquanto a coluna cargos.exige_cartao não decide. */
const CARGOS_COM_CARTAO_PADRAO = ["encarregado regional", "encarregado local", "examinadora"];

/** Cargos que só aceitam o instrumento Órgão enquanto a coluna cargos.somente_orgao não decide. */
const CARGOS_SOMENTE_ORGAO_PADRAO = ["organista", "examinadora", "instrutor"];

/** O cargo só pode usar o instrumento Órgão? (Organista, Examinadora, Instrutor e Instrutora.) */
export function cargoSomenteOrgao(cargo: CargoCadastro | null | undefined): boolean {
  if (!cargo) return false;
  if (typeof cargo.somente_orgao === "boolean") return cargo.somente_orgao;
  const nome = semAcento(cargo.nome);
  return CARGOS_SOMENTE_ORGAO_PADRAO.some((prefixo) => nome.startsWith(prefixo));
}

/** O instrumento é um Órgão? (mesma regra do banco: o nome tem "orgao", sem acento.) */
export function instrumentoEOrgao(nome: string | null | undefined): boolean {
  return !!nome && semAcento(nome).includes("orgao");
}

/** Instrumentos que o cargo aceita: todos, ou só os Órgãos nos cargos travados. */
export function instrumentosDoCargo<T extends { nome: string }>(instrumentos: T[], somenteOrgao: boolean): T[] {
  return somenteOrgao ? instrumentos.filter((instrumento) => instrumentoEOrgao(instrumento.nome)) : instrumentos;
}

export function cargoEntraNoCadastro(nomeCargo: string | null | undefined): boolean {
  if (!nomeCargo) return false;
  const nome = semAcento(nomeCargo);
  return CARGOS_DO_CADASTRO.some((prefixo) => nome.startsWith(prefixo));
}

/**
 * Cargos oferecidos no formulário. Na edição, o cargo atual do membro continua na lista mesmo que seja
 * um cargo antigo (ex.: Ancião), para não apagar nem trocar o cargo sem querer.
 */
export function cargosDoCadastro<T extends CargoCadastro>(cargos: T[], cargoAtualId?: string | null): T[] {
  return cargos.filter((cargo) => cargoEntraNoCadastro(cargo.nome) || cargo.id === cargoAtualId);
}

/** O cargo exige o cartão de identificação (número, validade...)? */
export function cargoExigeCartao(cargo: CargoCadastro | null | undefined): boolean {
  if (!cargo) return false;
  if (typeof cargo.exige_cartao === "boolean") return cargo.exige_cartao;
  const nome = semAcento(cargo.nome);
  return CARGOS_COM_CARTAO_PADRAO.some((prefixo) => nome.startsWith(prefixo));
}

// ---------- Formatos de digitação ----------

export function somenteDigitos(texto: string, maximo?: number): string {
  const digitos = texto.replace(/\D/g, "");
  return maximo ? digitos.slice(0, maximo) : digitos;
}

/** "40000-000" (aceita digitação parcial). */
export function formatarCep(texto: string): string {
  const d = somenteDigitos(texto, 8);
  return d.length > 5 ? `${d.slice(0, 5)}-${d.slice(5)}` : d;
}

/** Telefone sem DDD: "99999-9999" (9 dígitos) ou "9999-9999" (8 dígitos). */
export function formatarTelefone(texto: string): string {
  const d = somenteDigitos(texto, 9);
  if (d.length > 8) return `${d.slice(0, 5)}-${d.slice(5)}`;
  return d.length > 4 ? `${d.slice(0, 4)}-${d.slice(4)}` : d;
}

/** WhatsApp com DDD: "(71) 99999-9999" (aceita digitação parcial). */
export function formatarWhatsapp(texto: string): string {
  const d = somenteDigitos(texto, 11);
  if (d.length <= 2) return d.length ? `(${d}` : "";
  const resto = d.slice(2);
  const corte = resto.length > 8 ? 5 : 4;
  return `(${d.slice(0, 2)}) ${resto.length > corte ? `${resto.slice(0, corte)}-${resto.slice(corte)}` : resto}`;
}

// ---------- Validação ----------

export function emailValido(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

/** Alguma informação do cadastro pessoal foi preenchida? (os campos "" e os Sim/Não vazios não contam) */
export function temAlgumDado(dados: CadastroMusical): boolean {
  return Object.values(dados).some((valor) => valor.trim() !== "");
}

export interface OpcoesValidacao {
  /** Exige todos os campos obrigatórios (cadastro novo, ou edição de quem já tem o cadastro preenchido). */
  completo: boolean;
  /** CPF só com os números. Obrigatório quando completo e o usuário pode vê-lo (permissão membros.cpf). */
  cpf: string;
  cpfObrigatorio: boolean;
  /** Data de nascimento (AAAA-MM-DD), que fica em "membros". */
  dataNascimento: string;
  /** Instrumento escolhido e se o cargo pede instrumento (obrigatório no cadastro completo). */
  instrumentoId: string;
  instrumentoObrigatorio: boolean;
  /** Já há (ou foi escolhido agora) um arquivo para a frente e para o verso do documento. */
  temDocumentoFrente: boolean;
  temDocumentoVerso: boolean;
  /** O cargo escolhido exige o cartão de identificação. */
  exigeCartao: boolean;
  /** Cidade e bairro ficam em "membros", mas são obrigatórios junto com o endereço. */
  cidade: string;
  bairro: string;
}

/** Confere o cadastro. Devolve a mensagem do primeiro problema ou null se estiver tudo certo. */
export function validarCadastro(dados: CadastroMusical, opcoes: OpcoesValidacao): string | null {
  const { completo, exigeCartao, cidade, bairro } = opcoes;
  const vazio = (texto: string) => texto.trim() === "";

  if (completo) {
    if (opcoes.cpfObrigatorio && vazio(opcoes.cpf)) return "Informe o CPF.";
    if (vazio(opcoes.dataNascimento)) return "Informe a data de nascimento.";
    if (vazio(dados.estado_civil)) return "Informe o estado civil.";
    if (vazio(dados.sexo)) return "Informe o sexo.";
    if (opcoes.instrumentoObrigatorio && vazio(opcoes.instrumentoId)) return "Informe o instrumento.";
    if (dados.batizado === "") return "Informe se a pessoa é batizada.";
    if (dados.batizado === "sim" && vazio(dados.data_batismo)) return "Informe a data do batismo.";
    if (dados.selado === "") return "Informe se a pessoa é selada.";
    if (vazio(dados.ddd) || vazio(dados.telefone)) return "Informe o DDD e o telefone.";
    if (dados.tem_whatsapp === "") return "Informe se o telefone tem WhatsApp.";
    if (vazio(dados.cep)) return "Informe o CEP.";
    if (vazio(dados.endereco)) return "Informe o endereço.";
    if (vazio(dados.numero)) return "Informe o número do endereço.";
    if (vazio(dados.uf)) return "Informe o estado (UF).";
    if (vazio(cidade)) return "Informe a cidade.";
    if (vazio(bairro)) return "Informe o bairro.";
    if (!opcoes.temDocumentoFrente) return "Anexe a frente do documento.";
    if (!opcoes.temDocumentoVerso) return "Anexe o verso do documento.";
  }

  if (
    dados.batizado === "sim" &&
    !vazio(dados.data_batismo) &&
    !vazio(opcoes.dataNascimento) &&
    dados.data_batismo < opcoes.dataNascimento
  ) {
    return "A data do batismo não pode ser anterior ao nascimento.";
  }

  if (!vazio(dados.ddd) && !/^\d{2}$/.test(dados.ddd)) return "O DDD deve ter 2 números.";
  if (!vazio(dados.telefone) && !/^\d{8,9}$/.test(dados.telefone)) return "O telefone deve ter 8 ou 9 números.";
  if (dados.tem_whatsapp === "sim" && !vazio(dados.whatsapp) && !/^\d{10,11}$/.test(dados.whatsapp)) {
    return "O WhatsApp deve ter o DDD e 8 ou 9 números.";
  }
  if (!vazio(dados.email) && !emailValido(dados.email)) return "O e-mail informado não é válido.";
  if (!vazio(dados.cep) && !/^\d{8}$/.test(dados.cep)) return "O CEP deve ter 8 números.";
  if (!vazio(dados.uf) && !(UFS as readonly string[]).includes(dados.uf)) return "Escolha um estado (UF) da lista.";

  if (exigeCartao) {
    if (vazio(dados.cartao_numero)) return "Informe o número do cartão de identificação.";
    if (vazio(dados.cartao_validade)) return "Informe a validade do cartão de identificação.";
  }
  if (!vazio(dados.cartao_emissao) && !vazio(dados.cartao_validade) && dados.cartao_emissao > dados.cartao_validade) {
    return "A validade do cartão não pode ser anterior à emissão.";
  }
  return null;
}

// ---------- Conversão com o banco ----------

type Bruto = Record<string, unknown>;

const texto = (valor: unknown): string => (typeof valor === "string" ? valor : "");
const simNao = (valor: unknown): SimNao => (valor === true ? "sim" : valor === false ? "nao" : "");

/** Resposta de obter_cadastro_musical (JSON do banco) -> dados do formulário. */
export function deRetornoDoBanco(bruto: unknown): CadastroMusical {
  const b = (bruto && typeof bruto === "object" ? bruto : {}) as Bruto;
  return {
    estado_civil: texto(b.estado_civil),
    sexo: texto(b.sexo),
    // Cadastros antigos (sem a coluna preenchida): quem tem data de batismo é batizado
    batizado: typeof b.batizado === "boolean" ? simNao(b.batizado) : texto(b.data_batismo) !== "" ? "sim" : "",
    data_batismo: texto(b.data_batismo),
    selado: simNao(b.selado),
    ddd: texto(b.ddd),
    telefone: texto(b.telefone),
    tem_whatsapp: simNao(b.tem_whatsapp),
    whatsapp: texto(b.whatsapp),
    email: texto(b.email),
    cep: texto(b.cep),
    endereco: texto(b.endereco),
    numero: texto(b.numero),
    complemento: texto(b.complemento),
    uf: texto(b.uf),
    cartao_numero: texto(b.cartao_numero),
    cartao_emissao: texto(b.cartao_emissao),
    cartao_validade: texto(b.cartao_validade),
    apresentado_em: texto(b.apresentado_em),
    apresentado_por: texto(b.apresentado_por),
    observacao: texto(b.observacao),
    documento_frente_path: texto(b.documento_frente_path),
    documento_verso_path: texto(b.documento_verso_path),
  };
}

/**
 * Dados do formulário -> JSON para salvar_cadastro_musical (campos vazios viram null).
 * Se tem WhatsApp e o número ficou vazio, usa o próprio telefone (DDD + número).
 * Se não tem WhatsApp, o número do WhatsApp não é guardado.
 * Se não é batizado, a data do batismo não é guardada.
 */
export function paraEnvioAoBanco(dados: CadastroMusical): Record<string, string | boolean | null> {
  const t = (valor: string) => (valor.trim() === "" ? null : valor.trim());
  const b = (valor: SimNao) => (valor === "sim" ? true : valor === "nao" ? false : null);

  let whatsapp: string | null = null;
  if (dados.tem_whatsapp === "sim") {
    whatsapp = t(somenteDigitos(dados.whatsapp)) ?? t(`${dados.ddd}${dados.telefone}`);
  }
  return {
    estado_civil: t(dados.estado_civil),
    sexo: t(dados.sexo),
    batizado: b(dados.batizado),
    data_batismo: dados.batizado === "sim" ? t(dados.data_batismo) : null,
    selado: b(dados.selado),
    ddd: t(dados.ddd),
    telefone: t(dados.telefone),
    tem_whatsapp: b(dados.tem_whatsapp),
    whatsapp,
    email: t(dados.email),
    cep: t(dados.cep),
    endereco: t(dados.endereco),
    numero: t(dados.numero),
    complemento: t(dados.complemento),
    uf: t(dados.uf),
    cartao_numero: t(dados.cartao_numero),
    cartao_emissao: t(dados.cartao_emissao),
    cartao_validade: t(dados.cartao_validade),
    apresentado_em: t(dados.apresentado_em),
    apresentado_por: t(dados.apresentado_por),
    observacao: t(dados.observacao),
    documento_frente_path: t(dados.documento_frente_path),
    documento_verso_path: t(dados.documento_verso_path),
  };
}

// ---------- Endereço pelo CEP (ViaCEP) ----------

/** O que o CEP preenche no formulário (campo vazio = o serviço não trouxe aquele dado). */
export interface EnderecoDoCep {
  endereco: string; // logradouro (rua, avenida...)
  complemento: string;
  bairro: string;
  cidade: string;
  uf: string;
}

/**
 * Resposta do ViaCEP (https://viacep.com.br/ws/CEP/json/) -> dados do formulário.
 * Devolve null quando o CEP não existe (o serviço responde {"erro": true}) ou a resposta é inválida.
 * CEP "geral" de cidade pequena vem sem rua e sem bairro: o que faltar o usuário digita.
 */
export function enderecoDoViaCep(bruto: unknown): EnderecoDoCep | null {
  if (!bruto || typeof bruto !== "object") return null;
  const b = bruto as Bruto;
  if (b.erro === true || b.erro === "true") return null;
  const uf = texto(b.uf).trim().toUpperCase();
  const cidade = texto(b.localidade).trim();
  if (!(UFS as readonly string[]).includes(uf) && cidade === "") return null; // resposta sem nada útil
  return {
    endereco: texto(b.logradouro).trim(),
    complemento: texto(b.complemento).trim(),
    bairro: texto(b.bairro).trim(),
    cidade,
    uf: (UFS as readonly string[]).includes(uf) ? uf : "",
  };
}
