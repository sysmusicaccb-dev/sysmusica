"use client";

/**
 * SysMúsica — Grade de permissões de um grupo (um bloco por módulo, uma caixa por ação).
 * Marcar uma ação marca "visualizar" junto; desmarcar "visualizar" limpa o módulo (veja regras.ts).
 */
import { alternarModulo, alternarPermissao, agruparPermissoesPorModulo } from "../regras";
import type { PermissaoCatalogo } from "../tipos";

interface MatrizPermissoesProps {
  catalogo: PermissaoCatalogo[];
  selecionadas: ReadonlySet<string>;
  onAlterar: (novas: Set<string>) => void;
  desabilitado?: boolean;
}

export default function MatrizPermissoes({
  catalogo,
  selecionadas,
  onAlterar,
  desabilitado = false,
}: MatrizPermissoesProps) {
  const modulos = agruparPermissoesPorModulo(catalogo);

  return (
    <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
      {modulos.map((modulo) => {
        const todasMarcadas = modulo.itens.every((item) => selecionadas.has(item.codigo));

        return (
          <div key={modulo.chave} className="px-4 py-3">
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm font-semibold text-slate-900">{modulo.titulo}</p>
              <button
                type="button"
                onClick={() => onAlterar(alternarModulo(selecionadas, modulo))}
                disabled={desabilitado}
                className="text-xs font-medium text-brand-700 hover:underline disabled:cursor-not-allowed disabled:opacity-50 disabled:no-underline"
              >
                {todasMarcadas ? "Limpar" : "Marcar todas"}
              </button>
            </div>
            <div className="mt-2 flex flex-wrap gap-x-5 gap-y-2">
              {modulo.itens.map((item) => (
                <label
                  key={item.codigo}
                  title={item.descricao}
                  className="flex items-center gap-2 text-sm text-slate-700"
                >
                  <input
                    type="checkbox"
                    checked={selecionadas.has(item.codigo)}
                    disabled={desabilitado}
                    onChange={() => onAlterar(alternarPermissao(selecionadas, item.codigo, catalogo))}
                    className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
                  />
                  {item.acao}
                </label>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}
