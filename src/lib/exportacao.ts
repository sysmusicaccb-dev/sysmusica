/**
 * SysMúsica — Saída de dados: impressão em janela própria (sem menu nem barra lateral) e exportação CSV.
 * Usado pela Auditoria e, em seguida, pelos Relatórios. As funções "montar..." e "gerar..." são puras
 * (testadas em exportacao.test.ts); só imprimirTabela e baixarCsv mexem no navegador.
 */

/** Troca os símbolos do HTML por texto seguro (evita que um dado vire código na página impressa). */
export function escaparHtml(texto: string): string {
  return texto
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export type OrientacaoPagina = "retrato" | "paisagem";

export interface OpcoesImpressao {
  titulo: string;
  subtitulo?: string;
  colunas: string[];
  linhas: string[][];
  orientacao?: OrientacaoPagina; // padrão: paisagem
  /** Ajuste MANUAL: zoom em porcentagem (ex.: 85). Sem valor = ajuste automático à largura da página. */
  escala?: number;
  /** Ajuste MANUAL: tamanho da letra em pt. Sem valor = automático conforme o número de colunas. */
  tamanhoFonte?: number;
  rodape?: string;
  /** Texto de data/hora da geração (padrão: agora, no fuso de Salvador). */
  geradoEm?: string;
  /** Abre a caixa de impressão sozinha (padrão: sim). Com "false", mostra a página para conferir e o botão Imprimir. */
  abrirImpressao?: boolean;
}

/**
 * Tamanho de letra automático: quanto mais colunas, menor a letra, para a tabela caber na largura da
 * página (o texto das células quebra de linha em vez de estourar a margem).
 */
export function calcularFonteAutomatica(numColunas: number, orientacao: OrientacaoPagina): number {
  const base = orientacao === "paisagem" ? 10 : 9.5;
  const limiteSemReducao = orientacao === "paisagem" ? 8 : 6;
  const excesso = Math.max(0, numColunas - limiteSemReducao);
  return Math.max(6.5, Math.round((base - excesso * 0.6) * 10) / 10);
}

/** Monta o documento HTML completo da impressão (título, tabela com cabeçalho repetido a cada página e rodapé). */
export function montarHtmlImpressao(opcoes: OpcoesImpressao): string {
  const orientacao = opcoes.orientacao ?? "paisagem";
  const fonte = opcoes.tamanhoFonte ?? calcularFonteAutomatica(opcoes.colunas.length, orientacao);
  const zoom = opcoes.escala && opcoes.escala > 0 ? opcoes.escala / 100 : 1;
  const gerado = opcoes.geradoEm ?? new Date().toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" });

  const cabecalho = opcoes.colunas.map((coluna) => `<th>${escaparHtml(coluna)}</th>`).join("");
  const corpo = opcoes.linhas
    .map(
      (linha) =>
        `<tr>${opcoes.colunas.map((_, indice) => `<td>${escaparHtml(linha[indice] ?? "")}</td>`).join("")}</tr>`
    )
    .join("");

  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>${escaparHtml(opcoes.titulo)}</title>
<style>
  @page { size: A4 ${orientacao === "paisagem" ? "landscape" : "portrait"}; margin: 10mm; }
  * { box-sizing: border-box; }
  body { font-family: Arial, Helvetica, sans-serif; color: #111; margin: 0; padding: 12px; zoom: ${zoom}; }
  h1 { font-size: ${fonte + 5}pt; margin: 0 0 2px; }
  .sub { font-size: ${fonte}pt; color: #444; margin: 0 0 8px; }
  table { width: 100%; border-collapse: collapse; font-size: ${fonte}pt; }
  th, td { border: 1px solid #999; padding: 2px 4px; text-align: left; vertical-align: top; overflow-wrap: anywhere; word-break: break-word; }
  th { background: #e5e7eb; }
  thead { display: table-header-group; }
  tr { page-break-inside: avoid; }
  .rodape { font-size: ${Math.max(6, fonte - 1)}pt; color: #555; margin-top: 8px; }
  .acoes { margin-bottom: 8px; }
  .acoes button { font-size: 11pt; padding: 6px 14px; }
  @media print { .acoes { display: none; } body { padding: 0; } }
</style>
</head>
<body>
<div class="acoes"><button type="button" onclick="window.print()">Imprimir</button></div>
<h1>${escaparHtml(opcoes.titulo)}</h1>
${opcoes.subtitulo ? `<p class="sub">${escaparHtml(opcoes.subtitulo)}</p>` : ""}
<table>
<thead><tr>${cabecalho}</tr></thead>
<tbody>${corpo}</tbody>
</table>
<p class="rodape">${opcoes.rodape ? `${escaparHtml(opcoes.rodape)} · ` : ""}Gerado em ${escaparHtml(gerado)} · ${opcoes.linhas.length} registro(s)</p>
${opcoes.abrirImpressao === false ? "" : `<script>window.addEventListener("load", function () { setTimeout(function () { window.focus(); window.print(); }, 150); });</script>`}
</body>
</html>`;
}

/**
 * Abre a janela do relatório JÁ NO CLIQUE do usuário (antes de qualquer espera), para o navegador não a
 * bloquear como pop-up. Depois, escreverImpressao preenche a janela. Devolve nulo se foi bloqueada.
 */
export function abrirJanelaImpressao(): Window | null {
  const janela = window.open("", "_blank");
  if (janela) {
    janela.document.open();
    janela.document.write(
      '<!doctype html><meta charset="utf-8"><title>Relatório</title><p style="font-family:Arial,sans-serif">Preparando o relatório...</p>'
    );
    janela.document.close();
  }
  return janela;
}

/** Escreve o relatório na janela aberta por abrirJanelaImpressao. */
export function escreverImpressao(janela: Window, opcoes: OpcoesImpressao): void {
  janela.document.open();
  janela.document.write(montarHtmlImpressao(opcoes));
  janela.document.close();
}

/** Abre a janela de impressão. Devolve false se o navegador bloqueou a janela (pop-up). */
export function imprimirTabela(opcoes: OpcoesImpressao): boolean {
  const janela = window.open("", "_blank");
  if (!janela) return false;
  janela.document.open();
  janela.document.write(montarHtmlImpressao(opcoes));
  janela.document.close();
  return true;
}

/**
 * Gera o texto CSV (separador ponto e vírgula e acentos corretos para o Excel em português).
 * Células que começariam com = + - @ ganham um apóstrofo na frente, para o Excel não executá-las como fórmula.
 */
export function gerarCsv(colunas: string[], linhas: string[][]): string {
  const celula = (valor: string): string => {
    let texto = valor.replace(/\r?\n/g, " ");
    if (/^[=+\-@\t\r]/.test(texto)) texto = `'${texto}`;
    return `"${texto.replace(/"/g, '""')}"`;
  };
  const todas = [colunas, ...linhas];
  return "\uFEFF" + todas.map((linha) => linha.map(celula).join(";")).join("\r\n");
}

/** Baixa o arquivo CSV no navegador. */
export function baixarCsv(nomeArquivo: string, conteudo: string): void {
  const blob = new Blob([conteudo], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = nomeArquivo;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
