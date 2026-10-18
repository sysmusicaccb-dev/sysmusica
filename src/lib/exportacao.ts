/**
 * SysMúsica — Saída de dados: impressão em janela própria (sem menu nem barra lateral) e exportação CSV.
 * Usado pela Auditoria e pelos Relatórios. As funções "montar...", "gerar..." e "urlSegura" são puras
 * (testadas em exportacao.test.ts); só imprimirTabela, abrirJanelaImpressao, escreverImpressao e baixarCsv
 * mexem no navegador.
 *
 * A folha impressa tem: faixa de título com a marca, quadro de informações (cabeçalho), tabela com
 * cabeçalho repetido a cada página e linhas alternadas, linhas de assinatura (opcionais) e rodapé.
 * Margens: a margem da página (escolhida) mais uma margem interna mínima de 4 mm, que protege o texto
 * mesmo se a caixa de impressão estiver em "Margens: Nenhuma".
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

/** Uma linha do quadro de informações do cabeçalho (ex.: "Evento: 17/10/2026 19:30 · Ensaio Regional"). */
export interface ItemInformacao {
  rotulo: string;
  valor: string;
  /** Ocupa a linha inteira do quadro (para textos longos, como o nome do evento). */
  largo?: boolean;
}

export interface OpcoesImpressao {
  titulo: string;
  subtitulo?: string;
  colunas: string[];
  linhas: string[][];
  orientacao?: OrientacaoPagina; // padrão: paisagem (os Relatórios mandam retrato)
  /** Ajuste MANUAL: zoom em porcentagem (ex.: 85). Sem valor = ajuste automático à largura da página. */
  escala?: number;
  /** Ajuste MANUAL: tamanho da letra em pt. Sem valor = automático conforme o número de colunas. */
  tamanhoFonte?: number;
  /** Margem da página em mm (padrão 12). */
  margem?: number;
  /** Texto livre do rodapé (usado só quando "rodapeItens" não é informado). */
  rodape?: string;
  /**
   * Itens do rodapé, separados por "·". Se informado, substitui o rodapé padrão; lista vazia = sem rodapé.
   * Sem esta opção, o rodapé é: texto livre · Gerado em ... · N registro(s).
   */
  rodapeItens?: string[];
  /** Texto de data/hora da geração (padrão: agora, no fuso de Salvador). */
  geradoEm?: string;
  /** Abre a caixa de impressão sozinha (padrão: sim). Com "false", mostra a página para conferir e o botão Imprimir. */
  abrirImpressao?: boolean;
  /** Nome da marca no topo (ex.: "SysMúsica"). */
  marca?: string;
  /** Logomarca: endereço https, caminho do próprio site (/logo.png) ou imagem embutida (data:image). */
  logoUrl?: string;
  /** Quadro de informações do cabeçalho (itens com valor vazio são ignorados). */
  informacoes?: ItemInformacao[];
  /** Numeração "Página X de Y" no canto da página (navegadores recentes, como Chrome e Edge). */
  paginacao?: boolean;
  /** Nomes das linhas de assinatura ao final (até 4). */
  assinaturas?: string[];
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

/** Aceita só endereços seguros para a logomarca; qualquer outra coisa (como "javascript:") vira nulo. */
export function urlSegura(url: string | undefined): string | null {
  if (!url) return null;
  const texto = url.trim();
  if (/^data:image\/(png|jpe?g|webp|gif|svg\+xml);base64,[a-z0-9+/=]+$/i.test(texto)) return texto;
  if (/^https:\/\/[^\s"'<>]+$/i.test(texto)) return texto;
  if (/^\/[^\s"'<>]*$/.test(texto) && !texto.startsWith("//")) return texto;
  return null;
}

// Margem entre 0 e 40 mm (padrão 12)
function limitarMargem(valor: number | undefined): number {
  if (valor === undefined || !Number.isFinite(valor)) return 12;
  return Math.min(40, Math.max(0, valor));
}

/** Monta o documento HTML completo da impressão. */
export function montarHtmlImpressao(opcoes: OpcoesImpressao): string {
  const orientacao = opcoes.orientacao ?? "paisagem";
  const fonte = opcoes.tamanhoFonte ?? calcularFonteAutomatica(opcoes.colunas.length, orientacao);
  const zoom = opcoes.escala && opcoes.escala > 0 ? opcoes.escala / 100 : 1;
  const margem = limitarMargem(opcoes.margem);
  const margemInferior = margem + (opcoes.paginacao ? 4 : 0); // espaço para a numeração das páginas
  const larguraFolha = orientacao === "paisagem" ? 297 : 210;
  const colunasInfo = orientacao === "paisagem" ? 3 : 2;
  const gerado = opcoes.geradoEm ?? new Date().toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" });

  // Numeração das páginas no canto inferior direito (só navegadores que aceitam caixas de margem)
  const caixaPaginas = opcoes.paginacao
    ? ' @bottom-right { content: "Página " counter(page) " de " counter(pages); font-family: Arial, sans-serif; font-size: 8pt; color: #475569; }'
    : "";

  // Marca: logomarca (se houver) e/ou nome
  const urlLogo = urlSegura(opcoes.logoUrl);
  const marcaHtml =
    urlLogo || opcoes.marca
      ? `<div class="marca">${urlLogo ? `<img class="logo" src="${escaparHtml(urlLogo)}" alt="">` : ""}${
          opcoes.marca ? `<span>${escaparHtml(opcoes.marca)}</span>` : ""
        }</div>`
      : "";

  // Quadro de informações do cabeçalho
  const informacoes = (opcoes.informacoes ?? []).filter((item) => item.valor.trim() !== "");
  const infoHtml =
    informacoes.length > 0
      ? `<section class="info">${informacoes
          .map(
            (item) =>
              `<div${item.largo ? ' class="largo"' : ""}><span class="r">${escaparHtml(item.rotulo)}:</span> <b>${escaparHtml(item.valor)}</b></div>`
          )
          .join("")}</section>`
      : "";

  const cabecalho = opcoes.colunas.map((coluna) => `<th>${escaparHtml(coluna)}</th>`).join("");
  const corpo = opcoes.linhas
    .map(
      (linha) =>
        `<tr>${opcoes.colunas.map((_, indice) => `<td>${escaparHtml(linha[indice] ?? "")}</td>`).join("")}</tr>`
    )
    .join("");

  // Linhas de assinatura (até 4)
  const nomesAssinaturas = (opcoes.assinaturas ?? []).slice(0, 4);
  const assinaturasHtml =
    nomesAssinaturas.length > 0
      ? `<section class="assinaturas">${nomesAssinaturas
          .map((nome) => `<div class="ass"><div class="traco"></div><span>${escaparHtml(nome)}</span></div>`)
          .join("")}</section>`
      : "";

  // Rodapé: itens escolhidos, ou o padrão (texto livre · Gerado em ... · N registro(s))
  const itensRodape =
    opcoes.rodapeItens ?? [
      ...(opcoes.rodape ? [opcoes.rodape] : []),
      `Gerado em ${gerado}`,
      `${opcoes.linhas.length} registro(s)`,
    ];
  const rodapeHtml =
    itensRodape.length > 0 ? `<footer class="rodape">${itensRodape.map(escaparHtml).join(" · ")}</footer>` : "";

  const script =
    opcoes.abrirImpressao === false
      ? ""
      : '<script>window.addEventListener("load", function () { setTimeout(function () { window.focus(); window.print(); }, 150); });</script>';

  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>${escaparHtml(opcoes.titulo)}</title>
<style>
  @page { size: A4 ${orientacao === "paisagem" ? "landscape" : "portrait"}; margin: ${margem}mm ${margem}mm ${margemInferior}mm;${caixaPaginas} }
  * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  body { font-family: Arial, Helvetica, sans-serif; color: #0f172a; margin: 0; zoom: ${zoom}; }
  .folha { padding: ${margem}mm; }
  .cab { display: flex; align-items: center; gap: 14px; padding-bottom: 8px; margin-bottom: 10px; border-bottom: 3px solid #4f46e5; }
  .marca { display: flex; align-items: center; gap: 8px; color: #4f46e5; font-weight: 700; font-size: ${fonte + 3}pt; white-space: nowrap; }
  .logo { height: 13mm; width: auto; }
  .tit { min-width: 0; flex: 1; }
  h1 { font-size: ${fonte + 6}pt; margin: 0; line-height: 1.15; }
  .sub { font-size: ${fonte + 1}pt; color: #475569; margin: 3px 0 0; }
  .info { display: grid; grid-template-columns: repeat(${colunasInfo}, minmax(0, 1fr)); gap: 3px 18px; margin: 0 0 10px; padding: 7px 10px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; font-size: ${fonte}pt; }
  .info .largo { grid-column: 1 / -1; }
  .info .r { color: #64748b; }
  table { width: 100%; border-collapse: collapse; font-size: ${fonte}pt; }
  th, td { padding: 3px 6px; text-align: left; vertical-align: top; overflow-wrap: anywhere; word-break: break-word; }
  th { background: #eef2ff; color: #1e1b4b; border-bottom: 2px solid #4f46e5; }
  td { border-bottom: 1px solid #e2e8f0; }
  tbody tr:nth-child(even) td { background: #f8fafc; }
  thead { display: table-header-group; }
  tr { page-break-inside: avoid; break-inside: avoid; }
  .assinaturas { display: flex; gap: 28px; margin-top: 34px; page-break-inside: avoid; break-inside: avoid; }
  .ass { flex: 1; text-align: center; font-size: ${fonte}pt; }
  .ass .traco { border-top: 1px solid #0f172a; margin-bottom: 3px; }
  .rodape { margin-top: 12px; padding-top: 6px; border-top: 1px solid #cbd5e1; font-size: ${Math.max(6, fonte - 1)}pt; color: #475569; }
  .acoes button { font-size: 11pt; padding: 6px 14px; cursor: pointer; }
  @media screen {
    body { background: #e5e7eb; padding: 12px; }
    .acoes { width: ${larguraFolha}mm; max-width: 100%; margin: 0 auto 8px; }
    .folha { width: ${larguraFolha}mm; margin: 0 auto; background: #fff; box-shadow: 0 1px 10px rgba(15, 23, 42, 0.25); }
  }
  @media print { body { background: #fff; padding: 0; } .acoes { display: none; } .folha { padding: 4mm; } }
</style>
</head>
<body>
<div class="acoes"><button type="button" onclick="window.print()">Imprimir</button></div>
<div class="folha">
<header class="cab">
${marcaHtml}<div class="tit"><h1>${escaparHtml(opcoes.titulo)}</h1>${opcoes.subtitulo ? `<p class="sub">${escaparHtml(opcoes.subtitulo)}</p>` : ""}</div>
</header>
${infoHtml}
<table>
<thead><tr>${cabecalho}</tr></thead>
<tbody>${corpo}</tbody>
</table>
${assinaturasHtml}
${rodapeHtml}
</div>
${script}
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
  escreverImpressao(janela, opcoes);
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
