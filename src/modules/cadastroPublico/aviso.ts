/**
 * Sysmusica — Aviso de privacidade do cadastro público (LGPD).
 *
 * ATENÇÃO (administradores): este texto é um modelo técnico, escrito para o Sysmusica. Antes de divulgar o link,
 * peça para o ministério/a CCB (e, se possível, um profissional de direito) revisar. Se o texto mudar de
 * significado, SUBA a versão (VERSAO_AVISO): o sistema grava, em cada cadastro, qual versão a pessoa aceitou.
 *
 * Os prazos abaixo são os mesmos aplicados pela limpeza automática do banco (migração 0042).
 */

/** Versão do texto aceito. Mude sempre que o texto mudar de significado. */
export const VERSAO_AVISO = "2026-10-v1";

/** Prazos de guarda dos cadastros que NÃO viraram membro (em dias). */
export const DIAS_PENDENTE_SEM_ANALISE = 60;
export const DIAS_REJEITADO_ATE_APAGAR = 30;

export interface ItemAviso {
  titulo: string;
  texto: string;
}

/**
 * Itens do aviso. `contato` é o e-mail (ou outro meio) para a pessoa exercer seus direitos; vem da variável
 * NEXT_PUBLIC_CONTATO_PRIVACIDADE. Sem ela, orienta procurar a secretaria da Casa de Oração.
 */
export function itensDoAviso(contato: string | null | undefined): ItemAviso[] {
  const meio = contato && contato.trim() !== "" ? contato.trim() : "a secretaria da sua Casa de Oração";
  return [
    {
      titulo: "Quem trata os seus dados",
      texto:
        "A administração musical da CCB da sua região, por meio do sistema Sysmusica, é quem analisa o seu cadastro e " +
        "decide como os dados são usados.",
    },
    {
      titulo: "Quais dados pedimos",
      texto:
        "Nome, CPF, data de nascimento, fotografia, documento de identificação (frente e verso), estado civil, sexo, " +
        "telefone, WhatsApp, e-mail, endereço, Casa de Oração, cargo e instrumento. Para alguns cargos, também os dados " +
        "do cartão de identificação. Para menores de 18 anos, o nome e o telefone do responsável.",
    },
    {
      titulo: "Dados sobre religião",
      texto:
        "Informar se você é batizado(a) e selado(a), e as datas, revela a sua crença religiosa, que a lei chama de dado " +
        "sensível. Por isso pedimos o seu consentimento específico para esses dados, e só os usamos para o cadastro " +
        "musical.",
    },
    {
      titulo: "Para que usamos",
      texto:
        "Avaliar e manter o seu cadastro musical, registrar a sua presença em ensaios e reuniões (portaria e QR Code) " +
        "e entrar em contato com você quando necessário. Não usamos os dados para publicidade.",
    },
    {
      titulo: "Quem pode ver",
      texto:
        "Somente pessoas autorizadas da CCB, da sua região. O CPF e o documento só podem ser vistos por quem recebeu " +
        "uma permissão específica. Não vendemos nem repassamos os dados. Os serviços de hospedagem e de banco de dados " +
        "do sistema armazenam as informações em nosso nome.",
    },
    {
      titulo: "Por quanto tempo guardamos",
      texto:
        `Enquanto o seu cadastro estiver ativo. Se ele não for aprovado, apagamos os seus dados e arquivos em até ` +
        `${DIAS_REJEITADO_ATE_APAGAR} dias depois da recusa, ou em ${DIAS_PENDENTE_SEM_ANALISE} dias se ninguém analisar.`,
    },
    {
      titulo: "Seus direitos",
      texto:
        `Você pode pedir a confirmação do tratamento, o acesso, a correção ou a exclusão dos seus dados, e retirar este ` +
        `consentimento quando quiser, falando com ${meio}.`,
    },
    {
      titulo: "Menores de 18 anos",
      texto:
        "O cadastro de menores só é enviado com o nome, o telefone e a concordância de um responsável.",
    },
  ];
}
