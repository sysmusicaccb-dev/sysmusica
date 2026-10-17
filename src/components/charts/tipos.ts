/**
 * SysMúsica — Tipos compartilhados pelos gráficos.
 */
export interface CorGrafico {
  texto: string; // classe de cor de traço (ex: "text-brand-600"), usada em SVG via currentColor
  fundo: string; // classe de cor de fundo (ex: "bg-brand-600"), usada em barras e legendas
}

export interface ItemGrafico {
  rotulo: string;
  valor: number;
  cor?: CorGrafico; // opcional: cor fixa (ex: status de presença); sem ela, usa a paleta
}
