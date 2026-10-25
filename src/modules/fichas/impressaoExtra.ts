/**
 * Sysmusica — Folhas impressas de M10 (avaliação de candidato), M11 (acompanhamento do GEM), pré-avaliação e
 * testes/exames de organistas e formulário de necessidade e entrega de instrumentos. Funções puras (testadas em
 * impressaoExtra.test.ts); tudo que vem do usuário é escapado.
 */
import { dataBr, dataPorExtenso, type DadosFicha } from "./dados";
import type { EntradaFichaImpressao } from "./impressao";
import {
  AREAS_GEM, COLUNAS_ORGANISTA, DESTINOS_ATENDIMENTO, ESCALA, FASES_NECESSIDADE, ITENS_NECESSIDADE, M10_LEITURA, M10_PRATICA,
  ORG_HINARIO, ORG_METODO, ORG_PRATICA, ORG_TEORIA, TOTAL_AULAS_GEM, TOTAL_AVALIACOES_GEM,
  chaveAula, chaveAval, chaveOrg, mediaGem, resultadosOrganista, rotulosResultado, type Linha,
} from "./layouts";
import type { ResultadoFicha } from "./tipos";

function esc(texto: string): string {
  return texto.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
const caixa = (marcada: boolean): string => (marcada ? "&#9746;" : "&#9744;"); // ☒ / ☐
const nl = (texto: string): string => esc(texto).replace(/\n/g, "<br>");
const n = (d: DadosFicha, chave: string): string => d.notas[chave] ?? "";

const LGPD =
  "“Autorizo a Congregação Cristã no Brasil – CCB a tratar meus dados pessoais, inclusive sensíveis, para a gestão da Música, os quais não serão divulgados a terceiros”.";

function campo(rotulo: string, valor: string): string {
  return `<div class="campo"><div class="valor">${esc(valor) || "&nbsp;"}</div><div class="rot">${esc(rotulo)}</div></div>`;
}
function linhaAss(rotulo: string): string {
  return `<div class="ass"><div class="linha"></div><div class="rot"><span>${esc(rotulo)}</span></div></div>`;
}
/** "☒ Sim ☐ Não" do resultado da ficha. */
function simNao(r: ResultadoFicha | null): string {
  return `${caixa(r === "APTO")} Sim &nbsp; ${caixa(r === "NAO_APTO")} Não`;
}

const ESTILO = `
@page { size: A4 portrait; margin: 12mm; }
* { box-sizing: border-box; }
body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #111; margin: 0; }
.acoes { padding: 8px; text-align: right; } .acoes button { font-size: 12pt; padding: 6px 14px; }
@media print { .acoes { display: none; } .quebra { page-break-before: always; } }
.folha { max-width: 186mm; margin: 0 auto; }
h1 { text-align: center; font-size: 14pt; margin: 3mm 0 5mm; } h3 { margin: 4mm 0 1mm; font-size: 10.5pt; }
h2 { font-size: 10.5pt; background: #e5e7eb; padding: 1mm 2mm; margin: 4mm 0 2mm; }
.campo { margin: 2.5mm 0; } .campo .valor { border-bottom: 1px solid #111; min-height: 5.5mm; padding: 0 1mm; font-size: 10.5pt; }
.rot { font-size: 8pt; color: #444; display: flex; justify-content: space-between; }
.g2 { display: grid; grid-template-columns: 1fr 1fr; gap: 5mm; } .g3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 5mm; }
.lgpd { font-size: 8.5pt; text-align: justify; margin: 3mm 0; }
.ass { margin: 8mm 0 1mm; } .ass .linha { border-bottom: 1px solid #111; }
table { width: 100%; border-collapse: collapse; margin: 2mm 0; } th, td { border: 1px solid #444; padding: 1mm 1.5mm; font-size: 9pt; vertical-align: top; }
th { background: #e5e7eb; text-align: center; } td.c { text-align: center; width: 12mm; } td.obs { min-height: 6mm; }
.rodape { margin-top: 6mm; display: flex; justify-content: space-between; font-size: 8pt; border-top: 1px solid #111; padding-top: 1mm; }
.txt { border: 1px solid #444; min-height: 12mm; padding: 1.5mm; font-size: 9.5pt; margin: 1mm 0 3mm; }
`;

function pagina(titulo: string, corpo: string, codigo: string, marca?: string, estiloExtra = ""): string {
  return `<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><title>${esc(codigo)}</title><style>${ESTILO}${estiloExtra}</style></head><body>
<div class="acoes"><button type="button" onclick="window.print()">Imprimir</button></div>
<div class="folha">
${titulo ? `<h1>${titulo}</h1>` : ""}
${corpo}
<div class="rodape"><span>COMISSÃO MUSICAL${marca ? " · " + esc(marca) : ""}</span><span>${esc(codigo)}</span></div>
</div>
</body></html>`;
}

/** Tabela com as quatro colunas de nota (Ótimo/Bom/Regular/Fraco) + coluna de texto livre. */
function tabelaNotas(titulo: string, linhas: Linha[], d: DadosFicha, textoRotulo: string, textoValor: string): string {
  const cab = ESCALA.map((o) => `<th>${esc(o.rotulo)}</th>`).join("");
  const corpo = linhas
    .map((l, i) => {
      const caixas = ESCALA.map((o) => `<td class="c">${caixa(n(d, `nota_${l.chave}`) === o.valor)}</td>`).join("");
      const texto = i === 0 ? `<td rowspan="${linhas.length}" style="width:55mm">${nl(textoValor)}</td>` : "";
      return `<tr><td>${esc(l.rotulo)}</td>${caixas}${texto}</tr>`;
    })
    .join("");
  return `<table><tr><th style="text-align:left">${esc(titulo)}</th>${cab}<th>${esc(textoRotulo)}</th></tr>${corpo}</table>`;
}

/** M10 — Ficha de avaliação de candidato a músico. */
function htmlM10(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const corpo = `<div class="g3">${campo("Nome do candidato", d.nome)}${campo("Instrumento", d.instrumento)}${campo("Data do teste", dataBr(d.data))}</div>
<div class="g3">${campo("Localidade", d.local)}${campo("Município", n(d, "municipio"))}${campo("Encarregado", n(d, "encarregado"))}</div>
<p class="lgpd">${LGPD}</p>
${tabelaNotas("LEIT. RÍTMICA/MÉTRICA", M10_LEITURA, d, "Lições / Hinos avaliados", n(d, "licoes_leitura"))}
${tabelaNotas("PRÁTICA INSTRUMENTAL", M10_PRATICA, d, "Escalas / Lições de método / Hinos avaliados", n(d, "licoes_pratica"))}
<h3>Hinos avaliados:</h3><div class="txt">${nl(n(d, "hinos"))}</div>
<p><b>Resultado final</b> &nbsp; Apto: ${simNao(e.resultado)} &nbsp;&nbsp; Nota da teoria: <b>${esc(n(d, "nota_teoria")) || "______"}</b></p>
${campo("Regional que realizou o exame", n(d, "regional"))}
${linhaAss("Assinatura do Encarregado Regional")}`;
  return pagina("FICHA DE AVALIAÇÃO DE CANDIDATO A MÚSICO", corpo, "FORMULÁRIO M10", e.marca);
}

/** M11 — Ficha de acompanhamento do GEM. */
function htmlM11(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const area = n(d, "area");
  const areas = AREAS_GEM.map((a) => `${caixa(area === a.valor)} ${esc(a.rotulo.toUpperCase())}`).join(" &nbsp;&nbsp; ");
  const marca = (v: string, valor: string) => caixa(v === valor);
  const linhasAula: string[] = [];
  for (let i = 1; i <= TOTAL_AULAS_GEM; i++) {
    const pres = n(d, chaveAula(i, "pres"));
    linhasAula.push(
      `<tr><td class="c">${String(i).padStart(2, "0")}</td><td class="c">${esc(dataBr(n(d, chaveAula(i, "data"))))}</td><td>${esc(n(d, chaveAula(i, "obs")))}</td>` +
        `<td class="c">${marca(pres, "P")} ${marca(pres, "A")} ${marca(pres, "J")} ${esc(n(d, chaveAula(i, "just")))}</td><td class="c">&nbsp;</td></tr>`,
    );
  }
  const linhasAval: string[] = [];
  for (let i = 1; i <= TOTAL_AVALIACOES_GEM; i++) {
    const pres = n(d, chaveAval(i, "pres"));
    linhasAval.push(
      `<tr><td class="c">${String(i).padStart(2, "0")}</td><td class="c">${esc(dataBr(n(d, chaveAval(i, "data"))))}</td><td class="c">${esc(n(d, chaveAval(i, "nota")))}</td><td>${esc(n(d, chaveAval(i, "obs")))}</td>` +
        `<td class="c">${marca(pres, "P")} ${marca(pres, "A")} ${marca(pres, "J")} ${esc(n(d, chaveAval(i, "just")))}</td><td class="c">&nbsp;</td></tr>`,
    );
  }
  const cabPres = "Pres. Aus. Just.*";
  const corpo = `<div class="g3">${campo("Aluno", d.nome)}${campo("Instrumento", d.instrumento)}${campo("Fase", n(d, "fase"))}</div>
<p class="lgpd">${LGPD}</p>
<p><b>${areas}</b></p>
<h2>PROGRAMAÇÃO DE AULAS TEÓRICAS</h2>
<table><tr><th>Nº Aula</th><th>Data</th><th>Anotações</th><th>${cabPres}</th><th>Visto Instrutor</th></tr>${linhasAula.join("")}</table>
<h2>AVALIAÇÕES</h2>
<table><tr><th>Aval. Nº</th><th>Data</th><th>Nota</th><th>Anotações</th><th>${cabPres}</th><th>Visto Instrutor</th></tr>${linhasAval.join("")}</table>
<p><b>MÉDIA:</b> ${esc(mediaGem(d.notas)) || "______"} &nbsp;&nbsp; <b>Resultado final</b> &nbsp; APTO: ${simNao(e.resultado)}</p>
<p style="font-size:8pt">* Justificativas: E - Enfermidade &nbsp; T - Trabalho &nbsp; V - Viagem &nbsp; O - Outros</p>
<div class="g2">${campo("Data", dataBr(d.data))}${linhaAss("Encarregado Local")}</div>`;
  return pagina("FICHA DE ACOMPANHAMENTO - GEM", corpo, "FORMULÁRIO M11", e.marca);
}

/** Pré-avaliação de candidatas a organistas / Testes e exames de organistas (mesma grade de 3 colunas). */
function htmlOrganistas(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const pre = e.tipo === "PRE_AVALIACAO_ORGANISTA";
  const col3 = (fn: (c: (typeof COLUNAS_ORGANISTA)[number]) => string): string =>
    COLUNAS_ORGANISTA.map((c) => `<td>${fn(c)}</td>`).join("");
  const notaLinha = (c: string, campo: string): string => {
    const v = n(d, chaveOrg(c, campo));
    return ESCALA.map((o) => `${caixa(v === o.valor)}${esc(o.rotulo)}`).join(" ");
  };
  const itens = (linhas: Linha[], tituloCol: (c: (typeof COLUNAS_ORGANISTA)[number]) => string): string =>
    `<tr>${COLUNAS_ORGANISTA.map((c) => `<th>${esc(tituloCol(c))}</th>`).join("")}</tr>` +
    linhas.map((l) => `<tr>${col3((c) => `<b>${esc(l.rotulo)}:</b> ${esc(n(d, chaveOrg(c.chave, l.chave)))}`)}</tr>`).join("");
  const praticas = ORG_PRATICA.map(
    (l) => `<tr>${col3((c) => `<b>${esc(l.rotulo)}</b> &nbsp; ${notaLinha(c.chave, `p_${l.chave}`)}`)}</tr>`,
  ).join("");
  const resultado = `<tr>${col3((c) => {
    const v = n(d, chaveOrg(c.chave, "resultado"));
    return "<b>RESULTADO</b> " + resultadosOrganista(c).map((o) => `${caixa(v === o.valor)} ${esc(o.rotulo)}`).join(" ");
  })}</tr>`;
  const exam = `<tr>${col3((c) => `Examinadora: ${esc(n(d, chaveOrg(c.chave, "examinadora"))) || "________________"}`)}</tr>`;
  const datas = `<tr>${col3((c) => `<b>DATA ${pre ? "TESTE" : "TESTE/EXAM"}:</b> ${esc(dataBr(n(d, chaveOrg(c.chave, "data")))) || "___/___/_____"}`)}</tr>`;
  const corpo = `<p style="text-align:center;margin:0"><b>CONGREGAÇÃO CRISTÃ NO BRASIL</b></p>
<div class="g2">${campo("Nome da candidata", d.nome)}${campo("Congregação", d.comum)}</div>
<div class="g2">${campo("Nome da professora", n(d, "professora"))}${campo("Congregação da professora", n(d, "professora_comum"))}</div>
<table>
<tr>${COLUNAS_ORGANISTA.map((c) => `<th>${esc(c.titulo.toUpperCase())}</th>`).join("")}</tr>
${itens(ORG_TEORIA, () => "Teoria e Solfejo")}
<tr>${col3((c) => `<b>AVALIAÇÃO TEÓRICA</b> &nbsp; ${notaLinha(c.chave, "aval_teorica")}`)}</tr>
${itens(ORG_METODO, (c) => c.metodo)}
${itens(ORG_HINARIO, () => "Hinário")}
${praticas}
${resultado}${exam}${datas}
</table>
<p style="font-size:8pt">Avaliação prática: use as linhas de nota (Ótimo, Bom, Regular, Fraco) conforme o teste ou exame de cada fase.</p>`;
  const titulo = pre ? "PRÉ AVALIAÇÃO DE CANDIDATAS A ORGANISTAS" : "TESTES E EXAMES DE ORGANISTAS";
  return pagina(titulo, corpo, pre ? "FICHA DE PRÉ-AVALIAÇÃO" : "FICHA DE TESTES E EXAMES", e.marca, "@page { size: A4 landscape; margin: 10mm; } .folha { max-width: 277mm; }");
}

/** Formulário de apresentação de necessidade e recibo de entrega de instrumentos (2 páginas: frente e verso). */
function htmlNecessidade(e: EntradaFichaImpressao): string {
  const d = e.dados;
  const dt = dataPorExtenso(d.data);
  const r = rotulosResultado("NECESSIDADE_INSTRUMENTO");
  const fase = FASES_NECESSIDADE.map((f) => `${caixa(n(d, "fase") === f.valor)} ${esc(f.rotulo.toUpperCase())}`).join(" &nbsp; ");
  const itens = ITENS_NECESSIDADE.map((i) => `${caixa(n(d, i.chave) === "1")} ${esc(i.rotulo.toUpperCase())}`).join(" &nbsp; ");
  const destino = DESTINOS_ATENDIMENTO.map((o) => `${caixa(n(d, "delib_destino") === o.valor)} ${esc(o.rotulo.toUpperCase())}`).join(" &nbsp; ");
  const frente = `<p style="text-align:center;margin:0"><b>CONGREGAÇÃO CRISTÃ NO BRASIL</b></p>
<p>REGIONAL ADMINISTRATIVA DE <b>${esc(n(d, "regional")) || "________________"}</b> &nbsp; DATA: <b>${dt.dia ? `${esc(dt.dia)}/${esc(dataBr(d.data).slice(3, 5))}/${esc(dt.ano)}` : "___/__/___"}</b></p>
<h1>FORMULÁRIO DE APRESENTAÇÃO DE NECESSIDADE E RECIBO DE ENTREGA DE INSTRUMENTOS MUSICAIS E ACESSÓRIOS</h1>
<h2>DADOS DO BENEFICIÁRIO E DA NECESSIDADE</h2>
${campo("Nome", d.nome)}
<div class="g2">${campo("Idade", n(d, "idade"))}${campo("Nome dos pais (se menor de idade)", n(d, "pais"))}</div>
<div class="g3">${campo("Congregação local", d.comum)}${campo("Setor", n(d, "setor"))}${campo("Cidade", d.local)}</div>
<p><b>FASE:</b> ${fase}</p>
<p><b>MOTIVO DA NECESSIDADE:</b></p><div class="txt">${nl(n(d, "motivo"))}</div>
<p>${itens}</p>
<p><b>ESPECIFICAR O INSTRUMENTO OU ACESSÓRIO NECESSÁRIO:</b></p><div class="txt">${nl(n(d, "especificar"))}</div>
<h2>VALORES DOS ORÇAMENTOS REALIZADOS (ANEXAR ORÇAMENTOS)</h2>
<div class="g3">${campo("1º orçamento", n(d, "orc1"))}${campo("2º orçamento", n(d, "orc2"))}${campo("3º orçamento", n(d, "orc3"))}</div>
<h2>NOME E ASSINATURA DO ENCARREGADO DE ORQUESTRA LOCAL E DIÁCONO LOCAL</h2>
<div class="g3">${campo("Encarregado local de orquestra", n(d, "nome_encarregado"))}${campo("Ministério local", n(d, "nome_ministerio"))}${campo("Diácono local", n(d, "nome_diacono"))}</div>
<div class="g3">${linhaAss("Assinatura")}${linhaAss("Assinatura")}${linhaAss("Assinatura")}</div>
<h2>DADOS DA REUNIÃO DE DELIBERAÇÃO DO ATENDIMENTO</h2>
<p>DATA <b>${esc(dataBr(n(d, "delib_data"))) || "____/____/_______"}</b> &nbsp; ${caixa(e.resultado === "APTO")} ${esc(r.sim.toUpperCase())} &nbsp; VALOR R$ <b>${esc(n(d, "delib_valor")) || "____________"}</b> &nbsp; ${caixa(e.resultado === "NAO_APTO")} ${esc(r.nao.toUpperCase())}</p>
<p>${destino}</p>
<h2>ASSINATURAS</h2>
<div class="g2"><div><b>Diáconos:</b>${linhaAss("")}${linhaAss("")}</div><div><b>Encarregados Regionais de Orquestras:</b>${linhaAss("")}${linhaAss("")}</div></div>`;
  const verso = `<h1>FORMULÁRIO DE APRESENTAÇÃO DE NECESSIDADE E RECIBO DE ENTREGA DE INSTRUMENTOS MUSICAIS E ACESSÓRIOS</h1>
<p class="lgpd">Faz parte do culto ministrado na Congregação Cristã no Brasil a apresentação musical, através de músicos que, sem qualquer remuneração, de forma voluntária e habitual, louvam a Deus com seus instrumentos musicais adquiridos com recursos próprios, custeando a manutenção e conservação. As orquestras foram formadas primeiramente para auxiliar a irmandade no canto dos hinos de louvores a Deus, mostrando-se um importante meio de propagação do Evangelho. Muitos jovens, adolescentes e adultos são despertados por Deus com o desejo de ingressarem nas orquestras, porém, pessoalmente, ou dentro das suas famílias, nem todos possuem condições financeiras para custear as aquisições e manutenções de seus instrumentos. A Congregação Cristã no Brasil nos termos do Artigo 18 de seu Estatuto, mantém assistência aos fiéis necessitados como parte de suas finalidades, assim, em casos especiais como estes, em que os músicos se comprometem a utilizar o instrumento musical apenas para este louvor sacro, eles poderão receber este santo atendimento que visa, primeiramente, prover o culto de músicos para auxiliar a irmandade no canto, e além disso, apoiar, integrar, estimular, e incluir, trazendo para dentro do convívio cristão o músico atendido, dando a este a mesma honra, dignidade e oportunidade que aos demais, trazendo assim, pela caridade de Deus no coração dos membros da igreja, a igualdade entre os irmãos que é a vontade de Deus.</p>
<h2>DECLARAÇÃO E RECIBO DE ENTREGA DO ATENDIMENTO</h2>
<p class="lgpd"><b>OBS:</b> Os atendimentos com itens em Estoque devem ser acompanhados da respectiva DT - Declaração de Trânsito. Os casos de compras com Nota Fiscal direto em nome do atendido não necessita emissão de DT, devendo arquivar a cópia da referida Nota Fiscal no Envelope.</p>
<p>Declaro que recebi o atendimento descrito no anverso e comprometo-me a utilizar o Instrumento Musical e acessórios apenas em louvor sacro. &nbsp; Data ______/______/_______</p>
<div class="g2">${campo("Nome", "")}${linhaAss("Assinatura")}</div>
<p class="lgpd"><b>Termo de Consentimento:</b> Autorizo e concordo com a disponibilização dos meus dados pessoais nos cadastros digitais e documentais da Obra da Piedade da Congregação para fins legais, contábeis e fiscais.<br><b>Termo de Compromisso:</b> A Congregação Cristã no Brasil compromete-se a gerir tais dados conforme disposto na LGPD Lei Geral de Proteção de Dados Pessoais, não divulgando a terceiros.</p>`;
  return pagina("", frente + `<div class="quebra"></div>` + verso, "FORMULÁRIO DE NECESSIDADE E ENTREGA", e.marca);
}

/** Despacho: devolve a folha se o tipo é um dos formulários "extra"; senão, nulo (quem chamou segue o fluxo normal). */
export function montarHtmlExtra(e: EntradaFichaImpressao): string | null {
  switch (e.tipo) {
    case "AVALIACAO_CANDIDATO": return htmlM10(e);
    case "ACOMPANHAMENTO_GEM": return htmlM11(e);
    case "PRE_AVALIACAO_ORGANISTA":
    case "EXAME_ORGANISTA": return htmlOrganistas(e);
    case "NECESSIDADE_INSTRUMENTO": return htmlNecessidade(e);
    default: return null;
  }
}
