/**
 * SysMúsica — Prévia do relatório na tela (as primeiras linhas). A impressão e o CSV trazem todas as
 * linhas; para ver o layout real da página, use "Pré-visualizar página".
 */

const LIMITE_NA_TELA = 100;

interface PreviaRelatorioProps {
  colunas: string[];
  linhas: string[][];
}

export default function PreviaRelatorio({ colunas, linhas }: PreviaRelatorioProps) {
  const mostradas = linhas.slice(0, LIMITE_NA_TELA);

  return (
    <div className="space-y-2">
      <div className="max-h-96 overflow-auto rounded-xl border border-slate-200">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="sticky top-0 bg-slate-50">
            <tr>
              {colunas.map((coluna, indice) => (
                <th
                  key={`${coluna}-${indice}`}
                  scope="col"
                  className="whitespace-nowrap px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500"
                >
                  {coluna}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {mostradas.length === 0 ? (
              <tr>
                <td colSpan={Math.max(colunas.length, 1)} className="px-3 py-8 text-center text-slate-500">
                  Nenhum registro com estes filtros.
                </td>
              </tr>
            ) : (
              mostradas.map((linha, indiceLinha) => (
                <tr key={indiceLinha} className="align-top">
                  {colunas.map((_, indiceColuna) => (
                    <td key={indiceColuna} className="px-3 py-2 text-slate-800">
                      {linha[indiceColuna]}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      {linhas.length > LIMITE_NA_TELA && (
        <p className="text-xs text-slate-500">
          Mostrando as primeiras {LIMITE_NA_TELA} de {linhas.length} linhas. A impressão e o CSV trazem todas.
        </p>
      )}
    </div>
  );
}
