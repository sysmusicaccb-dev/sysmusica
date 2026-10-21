/**
 * SysMúsica — Regras puras do Cadastro Musical PÚBLICO (sem banco, sem tela). Testadas em regras.test.ts.
 *
 * O formulário público usa as mesmas regras do cadastro interno (modules/membros/cadastroMusical.ts) e soma:
 *  - aceite do aviso de privacidade (LGPD) e campo-armadilha contra robôs;
 *  - menores de 18 anos: nome e telefone do responsável e o aceite dele;
 *  - fotografia e documento (frente e verso) sempre obrigatórios.
 * O banco refaz todas as conferências (função registrar_cadastro_publico, migração 0042): a tela é só a resposta rápida.
 */
import {
  cargoEntraNoCadastro,
  cargoExigeCartao,
  cargoSomenteOrgao,
  instrumentosDoCargo,
  paraEnvioAoBanco,
  somenteDigitos,
  validarCadastro,
  type CadastroMusical,
  type CargoCadastro,
} from "@/modules/membros/cadastroMusical";
import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { cargoUsaCategoria, validarCategoria } from "@/modules/painel/regras";
import { VERSAO_AVISO } from "./aviso";
import { cpfValido, soDigitos } from "./cpf";

export const IDADE_MAIORIDADE = 18;
export const NOME_MINIMO = 5;
export const NOME_MAXIMO = 120;
export const RESPONSAVEL_NOME_MINIMO = 3;

/** Cargo como a função opcoes_cadastro_publico devolve. */
export interface CargoPublico extends CargoCadastro {
  permite_instrumento: boolean;
  exige_instrumento: boolean;
}

export interface InstrumentoPublico {
  id: string;
  nome: string;
  familia_id: string | null;
}

export interface FamiliaPublica {
  id: string;
  nome: string;
}

/** Casa de Oração com o caminho na organização (para a pessoa achar a dela). */
export interface CasaPublica {
  id: string;
  nome: string;
  adm: string | null;
  ra: string | null;
  rrm: string | null;
  setor: string | null;
}

export interface OpcoesCadastroPublico {
  cargos: CargoPublico[];
  instrumentos: InstrumentoPublico[];
  familias: FamiliaPublica[];
  casas: CasaPublica[];
}

/** Tudo o que a pessoa preenche (textos, para ligar direto nos campos). */
export interface DadosFormularioPublico {
  nome: string;
  casaOracaoId: string; // id da casa escolhida na lista ("" se a pessoa digitou uma casa que não está na lista)
  casaNome: string; // nome digitado (usado só quando casaOracaoId está vazio)
  cargoId: string;
  instrumentoId: string;
  categoria: string;
  cpf: string;
  dataNascimento: string; // AAAA-MM-DD
  cidade: string;
  bairro: string;
  cadastro: CadastroMusical;
  responsavelNome: string;
  responsavelTelefone: string; // DDD + número
  aceiteResponsavel: boolean;
  aceitePrivacidade: boolean;
  /** Campo-armadilha: invisível para pessoas; robôs costumam preencher. Deve ficar vazio. */
  site: string;
}

/** Tamanho do nome de uma Casa de Oração digitada (mesmos limites do banco). */
export const CASA_NOME_MINIMO = 3;
export const CASA_NOME_MAXIMO = 120;

export interface ContextoValidacao {
  cargo: CargoPublico | undefined;
  temFoto: boolean;
  temDocumentoFrente: boolean;
  temDocumentoVerso: boolean;
  /** Data de hoje (AAAA-MM-DD), recebida de fora para a regra ser testável. */
  hoje: string;
}

/** Tira espaços das pontas e os repetidos do nome. */
export function limparNome(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** "AAAA-MM-DD" válida (existe no calendário)? */
export function dataIsoValida(texto: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) return false;
  const [a, m, d] = texto.split("-").map(Number);
  const data = new Date(Date.UTC(a, m - 1, d));
  return data.getUTCFullYear() === a && data.getUTCMonth() === m - 1 && data.getUTCDate() === d;
}

/** Idade em anos completos em `hoje` (AAAA-MM-DD); null se alguma data for inválida. */
export function idadeEm(dataNascimento: string, hoje: string): number | null {
  if (!dataIsoValida(dataNascimento) || !dataIsoValida(hoje)) return null;
  const [an, mn, dn] = dataNascimento.split("-").map(Number);
  const [ah, mh, dh] = hoje.split("-").map(Number);
  let idade = ah - an;
  if (mh < mn || (mh === mn && dh < dn)) idade -= 1;
  return idade;
}

export function ehMenorDeIdade(dataNascimento: string, hoje: string): boolean {
  const idade = idadeEm(dataNascimento, hoje);
  return idade !== null && idade < IDADE_MAIORIDADE;
}

export function formularioVazio(cadastroVazio: CadastroMusical): DadosFormularioPublico {
  return {
    nome: "",
    casaOracaoId: "",
    casaNome: "",
    cargoId: "",
    instrumentoId: "",
    categoria: "",
    cpf: "",
    dataNascimento: "",
    cidade: "",
    bairro: "",
    cadastro: cadastroVazio,
    responsavelNome: "",
    responsavelTelefone: "",
    aceiteResponsavel: false,
    aceitePrivacidade: false,
    site: "",
  };
}

/** Cargos oferecidos no formulário público: só os que têm Cadastro Musical. */
export function cargosDoFormularioPublico(cargos: CargoPublico[]): CargoPublico[] {
  return cargos.filter((cargo) => cargoEntraNoCadastro(cargo.nome));
}

/** Instrumentos que o cargo aceita (só Órgão nos cargos travados). */
export function instrumentosDoFormularioPublico(
  instrumentos: InstrumentoPublico[],
  cargo: CargoPublico | undefined
): InstrumentoPublico[] {
  return instrumentosDoCargo(instrumentos, cargoSomenteOrgao(cargo));
}

/**
 * Confere o formulário. Devolve a mensagem do primeiro problema ou null se estiver tudo certo.
 * Fica na ordem em que os campos aparecem na tela.
 */
export function validarEnvioPublico(dados: DadosFormularioPublico, ctx: ContextoValidacao): string | null {
  // Robô: mensagem genérica, sem explicar o motivo
  if (dados.site.trim() !== "") return "Não foi possível enviar o cadastro. Atualize a página e tente de novo.";

  if (!ctx.temFoto) return "A fotografia é obrigatória. Tire a foto ou escolha uma imagem.";

  const nome = limparNome(dados.nome);
  if (nome.length < NOME_MINIMO || !nome.includes(" ")) return "Informe o nome completo (nome e sobrenome).";
  if (nome.length > NOME_MAXIMO) return `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.`;

  const cpf = soDigitos(dados.cpf);
  if (cpf === "") return "Informe o CPF.";
  if (!cpfValido(cpf)) return "CPF inválido. Confira os números digitados.";

  if (dados.dataNascimento.trim() === "") return "Informe a data de nascimento.";
  if (!dataIsoValida(dados.dataNascimento)) return "Data de nascimento inválida.";
  if (dados.dataNascimento > ctx.hoje) return "A data de nascimento não pode estar no futuro.";
  if (dados.dataNascimento < "1900-01-01") return "Data de nascimento inválida.";

  // Casa de Oração: escolhida na lista OU digitada (quando não existe na lista; a secretaria confere depois)
  if (!dados.casaOracaoId) {
    const casa = limparNome(dados.casaNome);
    if (casa.length < CASA_NOME_MINIMO) return "Escolha a sua Casa de Oração na lista ou digite o nome dela.";
    if (casa.length > CASA_NOME_MAXIMO) return `O nome da Casa de Oração pode ter no máximo ${CASA_NOME_MAXIMO} caracteres.`;
  }

  const cargo = ctx.cargo;
  if (!dados.cargoId || !cargo) return "Escolha o cargo.";
  if (!cargoEntraNoCadastro(cargo.nome)) return "Este cargo não faz o cadastro por aqui. Procure a secretaria.";

  const erroCategoria = validarCategoria(cargo.nome, dados.categoria);
  if (erroCategoria) return erroCategoria;

  // No cadastro completo, todo cargo que aceita instrumento exige a escolha dele (mesma regra da tela interna).
  const permiteInstrumento = cargo.permite_instrumento;
  const erroInstrumento = validarInstrumentoDoCargo(permiteInstrumento, dados.instrumentoId, cargo.nome);
  if (erroInstrumento) return erroInstrumento;

  const erroCadastro = validarCadastro(dados.cadastro, {
    completo: true,
    exigeCartao: cargoExigeCartao(cargo),
    cidade: dados.cidade,
    bairro: dados.bairro,
    cpf,
    cpfObrigatorio: true,
    dataNascimento: dados.dataNascimento,
    instrumentoId: permiteInstrumento ? dados.instrumentoId : "",
    instrumentoObrigatorio: permiteInstrumento,
    temDocumentoFrente: ctx.temDocumentoFrente,
    temDocumentoVerso: ctx.temDocumentoVerso,
  });
  if (erroCadastro) return erroCadastro;

  if (ehMenorDeIdade(dados.dataNascimento, ctx.hoje)) {
    if (limparNome(dados.responsavelNome).length < RESPONSAVEL_NOME_MINIMO) {
      return "Para menores de 18 anos, informe o nome do responsável.";
    }
    if (!/^\d{10,11}$/.test(somenteDigitos(dados.responsavelTelefone))) {
      return "Informe o telefone do responsável com o DDD.";
    }
    if (!dados.aceiteResponsavel) return "O responsável precisa concordar com o cadastro.";
  }

  if (!dados.aceitePrivacidade) return "Para enviar, leia o aviso de privacidade e marque que concorda.";
  return null;
}

/** JSON que vai para a rota de envio (e dali para registrar_cadastro_publico). Chaves iguais às do banco. */
export interface CargaCadastroPublico {
  nome: string;
  casa_oracao_id: string; // "" quando a casa foi digitada
  casa_nome: string | null; // nome digitado (só quando não escolheu da lista)
  cargo_id: string;
  instrumento_id: string | null;
  categoria: string | null;
  cpf: string;
  data_nascimento: string;
  cidade: string;
  bairro: string;
  cadastro: Record<string, string | boolean | null>;
  responsavel_nome: string | null;
  responsavel_telefone: string | null;
  aceite_responsavel: boolean;
  aceite_privacidade: boolean;
  aviso_versao: string;
  site: string;
}

export function montarCargaPublica(dados: DadosFormularioPublico, ctx: Pick<ContextoValidacao, "cargo" | "hoje">): CargaCadastroPublico {
  const menor = ehMenorDeIdade(dados.dataNascimento, ctx.hoje);
  const permiteInstrumento = ctx.cargo?.permite_instrumento ?? false;
  // Os caminhos dos arquivos NÃO vão aqui: o servidor os conhece (pasta do envio).
  // Campos de uso interno (apresentação, observação) não existem no formulário público: sempre vazios.
  const cadastro = paraEnvioAoBanco({
    ...dados.cadastro,
    apresentado_em: "",
    apresentado_por: "",
    observacao: "",
    documento_frente_path: "",
    documento_verso_path: "",
  });
  delete cadastro.documento_frente_path;
  delete cadastro.documento_verso_path;
  return {
    nome: limparNome(dados.nome),
    casa_oracao_id: dados.casaOracaoId,
    casa_nome: dados.casaOracaoId ? null : limparNome(dados.casaNome),
    cargo_id: dados.cargoId,
    instrumento_id: permiteInstrumento && dados.instrumentoId ? dados.instrumentoId : null,
    categoria: cargoUsaCategoria(ctx.cargo?.nome) && dados.categoria ? dados.categoria : null,
    cpf: soDigitos(dados.cpf),
    data_nascimento: dados.dataNascimento,
    cidade: dados.cidade.trim(),
    bairro: dados.bairro.trim(),
    cadastro,
    responsavel_nome: menor ? limparNome(dados.responsavelNome) : null,
    responsavel_telefone: menor ? somenteDigitos(dados.responsavelTelefone) : null,
    aceite_responsavel: menor ? dados.aceiteResponsavel : false,
    aceite_privacidade: dados.aceitePrivacidade,
    aviso_versao: VERSAO_AVISO,
    site: dados.site,
  };
}

/** Mensagem exibida depois do envio (a mesma em qualquer situação: não revela se o CPF já existia). */
export const MENSAGEM_ENVIO_RECEBIDO =
  "Cadastro recebido! Ele será analisado pela secretaria. Se for aprovado, você passa a constar no sistema.";
