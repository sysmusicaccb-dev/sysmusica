/**
 * Sysmusica — Gráfico de colunas empilhadas (CSS próprio, sem biblioteca).
 * Cada coluna é uma categoria (ex: um evento) e cada trecho empilhado é um status.
 * A altura de cada coluna é proporcional ao maior total. Passe o mouse para ver os detalhes.
 */

export interface SegmentoColuna {
  rotulo: string;
  valor: number;
  corFundo: string; // classe de fundo do Tailwind, ex: "bg-emerald-500"
}

export interface ColunaEmpilhada {
  rotulo: string; // texto abaixo da coluna (ex: "13/10")
  titulo: string; // detalhe mostrado ao passar o mouse (e lido por leitores de tela)
  segmentos: SegmentoColuna[]; // o primeiro segmento fica embaixo
}

export interface ItemLegenda {
  rotulo: string;
  corFundo: string;
}

interface GraficoColunasEmpilhadasProps {
  colunas: ColunaEmpilhada[];
  legenda: ItemLegenda[];
  vazio?: string;
}

export default function GraficoColunasEmpilhadas({
  colunas,
  legenda,
  vazio = "Sem dados ainda.",
}: GraficoColunasEmpilhadasProps) {
  const totais = colunas.map((coluna) =>
    coluna.segmentos.reduce((soma, segmento) => soma + segmento.valor, 0)
  );
  const maximo = Math.max(...totais, 0);

  if (colunas.length === 0 || maximo === 0) {
    return <p className="py-8 text-center text-sm text-slate-500">{vazio}</p>;
  }

  return (
    <div>
      {/* Legenda */}
      <ul className="mb-4 flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate-600">
        {legenda.map((item) => (
          <li key={item.rotulo} className="flex items-center gap-1.5">
            <span className={`h-2.5 w-2.5 rounded-full ${item.corFundo}`} aria-hidden="true" />
            {item.rotulo}
          </li>
        ))}
      </ul>

      {/* Colunas */}
      <div className="flex h-44 items-end gap-2 border-b border-slate-200 sm:gap-3">
        {colunas.map((coluna, indice) => {
          const total = totais[indice];

          return (
            <div
              key={`${coluna.rotulo}-${indice}`}
              title={coluna.titulo}
              className="flex h-full min-w-0 flex-1 items-end justify-center"
            >
              {total > 0 && (
                <div
                  className="flex w-full max-w-14 flex-col-reverse overflow-hidden rounded-t-md"
                  style={{ height: `${Math.max((total / maximo) * 100, 4)}%` }}
                >
                  {coluna.segmentos.map(
                    (segmento) =>
                      segmento.valor > 0 && (
                        <div
                          key={segmento.rotulo}
                          className={segmento.corFundo}
                          style={{ height: `${(segmento.valor / total) * 100}%` }}
                        />
                      )
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Rótulos e totais, alinhados com as colunas */}
      <div className="mt-2 flex gap-2 sm:gap-3">
        {colunas.map((coluna, indice) => (
          <div key={`${coluna.rotulo}-${indice}`} className="min-w-0 flex-1 text-center">
            <p className="truncate text-xs font-medium text-slate-700">{coluna.rotulo}</p>
            <p className="text-[11px] text-slate-500">{totais[indice]}</p>
          </div>
        ))}
      </div>

      {/* Versão em texto para leitores de tela */}
      <ul className="sr-only">
        {colunas.map((coluna, indice) => (
          <li key={`${coluna.rotulo}-${indice}`}>{coluna.titulo}</li>
        ))}
      </ul>
    </div>
  );
}
