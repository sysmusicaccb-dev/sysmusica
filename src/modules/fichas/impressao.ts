/**
 * Sysmusica — Folha impressa dos formulários M01, M02, M03, M05, M07 e Avaliação RJM (mesmo texto e ordem dos PDFs da Comissão Musical).
 * Função pura: devolve o HTML completo da folha (testada em impressao.test.ts). Tudo que vem do usuário é escapado.
 */
import { montarHtmlExtra } from "./impressaoExtra";
import { DESTINOS_M05, MOTIVOS_M07, dataBr, dataPorExtenso, type DadosFicha, type TipoComFormulario } from "./dados";
import type { ResultadoFicha } from "./tipos";

export interface EntradaFichaImpressao {
  tipo: TipoComFormulario;
  dados: DadosFicha;
  resultado: ResultadoFicha | null;
  marca?: string;
}

function esc(texto: string): string {
  return texto.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

const caixa = (marcada: boolean): string => (marcada ? "&#9746;" : "&#9744;"); // ☒ / ☐

/** Campo com o texto preenchido em cima de uma linha (como no papel). */
function campo(rotulo: string, valor: string): string {
  return `<div class="campo"><div class="valor">${esc(valor) || "&nbsp;"}</div><div class="rot">${esc(rotulo)}</div></div>`;
}

/** Linha de assinatura em branco. */
function assinatura(cargo: string): string {
  return `<div class="ass"><div class="linha"></div><div class="rot"><span>${esc(cargo)}</span><span>Assinatura</span></div></div>`;
}

const LGPD =
  "“Autorizo a Congregação Cristã no Brasil – CCB a tratar meus dados pessoais, inclusive sensíveis, para a gestão da Música, os quais não serão divulgados a terceiros”.";

function declaracao(quem: string): string {
  return `${quem} acima declara estar ciente que exercerá voluntariamente a parte musical e que a Congregação Cristã não tem nenhum vínculo com escolas, conservatórios, faculdades ou qualquer outra entidade com fins lucrativos para o estudo musical. Não lhe será fornecido qualquer tipo de diploma, certificado ou atestado pelo aprendizado. Autoriza a inserção dos dados no Sistema de Administração Musical de propriedade da Congregação Cristã.`;
}

/** Casinha do resultado: "Apto: ☒ Sim ☐ Não". */
function caixaResultado(rotulo: string, r: ResultadoFicha | null): string {
  return `<div class="campo"><div class="valor">${rotulo}: ${caixa(r === "APTO")} Sim &nbsp; ${caixa(r === "NAO_APTO")} Não</div><div class="rot"><span>${rotulo}</span></div></div>`;
}

const ESTILO = `
@page { size: A4 portrait; margin: 14mm; }
* { box-sizing: border-box; }
body { font-family: Arial, Helvetica, sans-serif; font-size: 11pt; color: #111; margin: 0; }
.acoes { padding: 8px; text-align: right; } .acoes button { font-size: 12pt; padding: 6px 14px; }
@media print { .acoes { display: none; } }
.folha { max-width: 182mm; margin: 0 auto; }
h1 { text-align: center; font-size: 15pt; margin: 4mm 0 6mm; }
h2 { font-size: 11pt; background: #e5e7eb; padding: 1mm 2mm; margin: 5mm 0 2mm; }
.campo { margin: 3mm 0; } .campo .valor { border-bottom: 1px solid #111; min-height: 6mm; padding: 0 1mm; font-size: 11.5pt; }
.rot { font-size: 8.5pt; color: #444; display: flex; justify-content: space-between; }
.duas { display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }
.lgpd, .decl { font-size: 9pt; text-align: justify; margin: 4mm 0; }
.ass { margin: 9mm 0 1mm; } .ass .linha { border-bottom: 1px solid #111; }
.res { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6mm; align-items: end; }
.rodape { margin-top: 8mm; display: flex; justify-content: space-between; font-size: 8.5pt; border-top: 1px solid #111; padding-top: 1mm; }
`;

function pagina(titulo: string, corpo: string, codigo: string, marca?: string): string {
  return `<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><title>${esc(codigo)}</title><style>${ESTILO}</style></head><body>
<div class="acoes"><button type="button" onclick="window.print()">Imprimir</button></div>
<div class="folha">
<h1>${titulo}</h1>
${corpo}
<div class="rodape"><span>COMISSÃO MUSICAL${marca ? " · " + esc(marca) : ""}</span><span>${esc(codigo)}</span></div>
</div>
</body></html>`;
}

const MINISTERIO_LOCAL = (extra: string) =>
  `<h2>Ministério local</h2>${assinatura("Ancião")}${assinatura("Cooperador oficial")}${extra}`;

/** M01 — Cadastro para ingresso no GEM. */
function htmlM01(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const corpo = `<h2>Identificação</h2>
<div class="duas">${campo("Nome completo (sem abreviações)", d.nome)}${campo("Comum congregação (cidade - bairro)", d.comum)}</div>
<div class="res">${campo("Data de nascimento", dataBr(d.nascimento))}${campo("Estado civil", d.estado_civil)}${campo("Telefone / Celular", d.telefone)}</div>
<div class="duas">${campo("Instrumento e tonalidade", d.instrumento)}${campo("Data de início no GEM", dataBr(d.inicio_gem))}</div>
<div class="duas">${campo("Nome do responsável (apenas para menores de 18 anos)", d.responsavel_nome)}${campo("Grau de parentesco", d.parentesco)}</div>
<p class="lgpd">${LGPD}</p>
<h2>De acordo</h2>
<p class="decl">Estou ciente que deverei cumprir com os regulamentos que constam no histórico musical e instruções regulamentares para orquestras.</p>
<div class="duas">${assinatura("Aluno")}${assinatura("Responsável")}</div>
${MINISTERIO_LOCAL(assinatura("Encarregado local"))}`;
  return pagina("CADASTRO PARA INGRESSO NO GEM", corpo, "FORMULÁRIO M01", e.marca);
}

/** M07 — Pedido de troca de instrumento. */
function htmlM07(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const data = dataPorExtenso(d.data);
  const motivos = MOTIVOS_M07.map((m) => `${caixa(d.motivo === m.valor)} ${esc(m.rotulo)}`).join(" &nbsp; ");
  const corpo = `<p>Ao ministério, a paz de Deus. <span style="float:right">${esc(d.local)}, ${esc(data.dia)} de ${esc(data.mes)} de ${esc(data.ano)}</span></p>
<h2>Identificação</h2>
<div class="duas">${campo("Nome completo (sem abreviações)", d.nome)}${campo("Data da oficialização", dataBr(d.data_oficializacao))}</div>
${campo("Comum congregação", d.comum)}
<h2>Informações da troca</h2>
<div class="duas">${campo("Instrumento e tonalidade atual", d.instrumento_atual)}${campo("Instrumento e tonalidade que deseja tocar (conforme pág. 9 do M.O.O.)", d.instrumento_novo)}</div>
<p><b>Motivo da troca:</b> ${motivos}</p>
<p class="lgpd">${LGPD}</p>
<p class="decl">Conforme tópico 02 da reunião anual de encarregados regionais de outubro de 2015, a mudança de categoria de instrumento só poderá ser realizada em casos de enfermidade do irmão ou necessidade da orquestra, e após a aprovação do Ministério Espiritual, em comunhão com o encarregado regional e local. Lembramos também que a compra do instrumento, para tocar nos cultos, só poderá ser realizada após essa aprovação e só iniciará a tocar após o teste com o novo instrumento, realizado com o encarregado regional. Não se trata de nova oficialização.</p>
${MINISTERIO_LOCAL(assinatura("Encarregado regional") + assinatura("Encarregado local"))}
<h2>Reunião ministerial</h2>
<div class="res">${campo("Data", "")}${campo("Localidade", "")}${caixaResultado("Aprovado", null)}</div>
${assinatura("Ancião")}
<h2>Resultado da avaliação</h2>
<div class="res">${campo("Data", "")}${campo("Localidade", "")}${caixaResultado("Apto", e.resultado)}</div>
${assinatura("Encarregado regional")}`;
  return pagina("PEDIDO DE TROCA DE INSTRUMENTO", corpo, "FORMULÁRIO M07", e.marca);
}

export function montarHtmlFicha(e: EntradaFichaImpressao): string {
  const extra = montarHtmlExtra(e);
  if (extra !== null) return extra;
  if (e.tipo === "M01") return htmlM01(e);
  if (e.tipo === "M07") return htmlM07(e);
  return htmlPedidoAvaliacao(e);
}

/** M02, M03, M05 e Avaliação RJM (mesmo desenho do pedido de avaliação). */
function htmlPedidoAvaliacao(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const data = dataPorExtenso(d.data);
  const organista = e.tipo === "M05";
  const pedido = organista
    ? `Solicitamos a avaliação desta irmã para: ${DESTINOS_M05.map((x) => `${caixa(d.para === x.valor)} ${esc(x.rotulo)}`).join(" &nbsp; ")}`
    : `Solicitamos a avaliação deste irmão para <b>${e.tipo === "AVALIACAO_RJM" ? "REUNIÃO DE JOVENS E MENORES" : e.tipo === "M02" ? "CULTO OFICIAL" : "OFICIALIZAÇÃO"}</b>.`;

  const identificacao = organista
    ? campo("Nome completo (sem abreviações)", d.nome) + campo("Comum congregação", d.comum)
    : campo("Nome completo (sem abreviações)", d.nome) +
      `<div class="duas">${campo("Comum congregação", d.comum)}${campo("Instrumento e tonalidade", d.instrumento)}</div>`;

  const professora = organista
    ? `<h2>Professora</h2>${campo("Nome completo da professora (sem abreviações)", d.professora_nome)}${campo("Comum congregação da professora", d.professora_comum)}`
    : "";

  const assinaturasResultado =
    e.tipo === "M02" || e.tipo === "AVALIACAO_RJM"
      ? assinatura("Encarregado regional | Encarregado local")
      : e.tipo === "M03"
        ? assinatura("Ancião") + assinatura("Encarregado regional")
        : assinatura("Ancião") + assinatura("Examinadora");

  const codigo = `FORMULÁRIO ${e.tipo === "AVALIACAO_RJM" ? "M02" : e.tipo}`;
  const titulo = organista ? "PEDIDO DE AVALIAÇÃO DE ORGANISTA" : "PEDIDO DE AVALIAÇÃO DE MÚSICO";
  const apto = organista ? "Apta" : "Apto";

  return `<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><title>${esc(codigo)} - ${esc(d.nome)}</title>
<style>
@page { size: A4 portrait; margin: 14mm; }
* { box-sizing: border-box; }
body { font-family: Arial, Helvetica, sans-serif; font-size: 11pt; color: #111; margin: 0; }
.acoes { padding: 8px; text-align: right; } .acoes button { font-size: 12pt; padding: 6px 14px; }
@media print { .acoes { display: none; } }
.folha { max-width: 182mm; margin: 0 auto; }
h1 { text-align: center; font-size: 15pt; margin: 4mm 0 6mm; }
h2 { font-size: 11pt; background: #e5e7eb; padding: 1mm 2mm; margin: 5mm 0 2mm; }
.campo { margin: 3mm 0; } .campo .valor { border-bottom: 1px solid #111; min-height: 6mm; padding: 0 1mm; font-size: 11.5pt; }
.rot { font-size: 8.5pt; color: #444; display: flex; justify-content: space-between; }
.duas { display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }
.lgpd, .decl { font-size: 9pt; text-align: justify; margin: 4mm 0; }
.ass { margin: 9mm 0 1mm; } .ass .linha { border-bottom: 1px solid #111; }
.res { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6mm; align-items: end; }
.rodape { margin-top: 8mm; display: flex; justify-content: space-between; font-size: 8.5pt; border-top: 1px solid #111; padding-top: 1mm; }
</style></head><body>
<div class="acoes"><button type="button" onclick="window.print()">Imprimir</button></div>
<div class="folha">
<h1>${titulo}</h1>
<p>Ao ministério, a paz de Deus. <span style="float:right">${esc(d.local)}, ${esc(data.dia)} de ${esc(data.mes)} de ${esc(data.ano)}</span></p>
<p>${pedido}</p>
<h2>Identificação</h2>
${identificacao}
<p class="lgpd">${LGPD}</p>
${professora}
<p class="decl">${declaracao(organista ? "A organista" : "O músico")}</p>
<h2>Ministério local</h2>
${assinatura("Ancião")}${assinatura("Cooperador oficial")}${assinatura("Encarregado regional | Encarregado local")}
<h2>Resultado</h2>
<div class="res">${campo("Data", "")}${campo("Localidade", "")}<div class="campo"><div class="valor">${apto}: ${caixa(e.resultado === "APTO")} Sim &nbsp; ${caixa(e.resultado === "NAO_APTO")} Não</div><div class="rot"><span>${apto}</span></div></div></div>
${assinaturasResultado}
<div class="rodape"><span>COMISSÃO MUSICAL${e.marca ? " · " + esc(e.marca) : ""}</span><span>${esc(codigo)}</span></div>
</div>
</body></html>`;
}
