/**
 * Sysmusica — Script que aplica a aparência (modo, cor e tamanho da letra) ANTES da primeira pintura.
 * Vai dentro do <head> do layout raiz. Sem ele, a página abriria sempre no tema claro e só depois (quando o
 * sistema carrega) trocaria para o escuro, o que aparece como um "piscar".
 *
 * Lê a cópia das preferências deste aparelho (a mesma que armazenamento.ts grava) e confere cada valor: o que
 * for inválido volta ao padrão. As listas de valores vêm de regras.ts, então nunca ficam diferentes do resto
 * do sistema. Qualquer falha (sem armazenamento, dado quebrado) é ignorada e a página usa o padrão.
 */
import { CORES, FONTES, PREFERENCIAS_PADRAO, TEMAS } from "./regras";

// Mesma chave de armazenamento.ts (o teste confere que as duas coincidem)
const CHAVE = "sysmusica.preferencias";

const VALIDOS = {
  tema: TEMAS.map((item) => item.id),
  cor: CORES.map((item) => item.id),
  fonte: FONTES.map((item) => item.id),
};

export const SCRIPT_TEMA_INICIAL =
  "(function () {" +
  "try {" +
  `var padrao = ${JSON.stringify(PREFERENCIAS_PADRAO)};` +
  `var validos = ${JSON.stringify(VALIDOS)};` +
  "var salvo = {};" +
  `try { salvo = JSON.parse(localStorage.getItem(${JSON.stringify(CHAVE)}) || "{}") || {}; } catch (e) { salvo = {}; }` +
  "function escolher(campo) { var v = salvo[campo]; return validos[campo].indexOf(v) >= 0 ? v : padrao[campo]; }" +
  "var tema = escolher('tema');" +
  "if (tema === 'sistema') { tema = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'escuro' : 'claro'; }" +
  "var raiz = document.documentElement;" +
  "raiz.setAttribute('data-tema', tema);" +
  "raiz.setAttribute('data-cor', escolher('cor'));" +
  "raiz.setAttribute('data-fonte', escolher('fonte'));" +
  "} catch (e) {}" +
  "})();";
