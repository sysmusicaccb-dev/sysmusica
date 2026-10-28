"use client";

/**
 * Sysmusica — Editor dos CAMPOS EXTRAS de um perfil de evento (Entrega 3).
 * O administrador cria campos próprios (texto curto, texto longo, número, sim/não ou lista), define se são obrigatórios,
 * escolhe a ordem e pode desativá-los. Eles aparecem na tela Dados do Ensaio, no resumo e na impressão.
 * Campo já preenchido em algum ensaio não pode ser excluído nem mudar de tipo: o banco recusa; use "Ativo" para esconder.
 */
import { ChevronDown, ChevronUp, Plus, Trash2 } from "lucide-react";
import { cn } from "@/lib/cn";
import {
  MAXIMO_CAMPOS_EXTRAS,
  ROTULO_TIPO_CAMPO,
  TIPOS_CAMPO,
  novoIdCampoExtra,
  type CampoExtra,
  type ConfigEnsaio,
  type TipoCampoExtra,
} from "@/modules/ensaio/perfilConfig";

interface EditorCamposExtrasProps {
  config: ConfigEnsaio;
  onChange: (config: ConfigEnsaio) => void;
  disabled?: boolean;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function EditorCamposExtras({ config, onChange, disabled }: EditorCamposExtrasProps) {
  const campos = config.campos_extras;
  const trocar = (novos: CampoExtra[]) => onChange({ ...config, campos_extras: novos });
  const alterar = (indice: number, parte: Partial<CampoExtra>) => trocar(campos.map((c, i) => (i === indice ? { ...c, ...parte } : c)));
  const mover = (indice: number, passo: -1 | 1) => {
    const destino = indice + passo;
    if (destino < 0 || destino >= campos.length) return;
    const copia = [...campos];
    [copia[indice], copia[destino]] = [copia[destino], copia[indice]];
    trocar(copia);
  };
  const adicionar = () =>
    trocar([
      ...campos,
      { id: novoIdCampoExtra(campos.map((c) => c.id)), nome: "", tipo: "texto_curto", obrigatorio: false, ativo: true, opcoes: [] },
    ]);

  return (
    <section className="rounded-xl border border-slate-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-slate-200 bg-slate-50 px-4 py-2.5">
        <h3 className="text-sm font-semibold text-slate-900">
          Campos extras <span className="font-normal text-slate-500">({campos.length}/{MAXIMO_CAMPOS_EXTRAS})</span>
        </h3>
        <button
          type="button"
          onClick={adicionar}
          disabled={disabled || campos.length >= MAXIMO_CAMPOS_EXTRAS}
          className="inline-flex items-center gap-1.5 rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm transition hover:bg-brand-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <Plus className="h-3.5 w-3.5" aria-hidden="true" />
          Adicionar campo
        </button>
      </header>
      <div className="space-y-3 p-4">
        {campos.length === 0 ? (
          <p className="text-sm text-slate-500">
            Nenhum campo extra. Use &quot;Adicionar campo&quot; para criar, por exemplo, &quot;Observações do ensaio&quot;.
          </p>
        ) : (
          campos.map((campo, i) => (
            <div key={campo.id} className={cn("space-y-3 rounded-lg border border-slate-200 p-3", !campo.ativo && "bg-slate-50")}>
              <div className="flex flex-wrap items-end gap-3">
                <div className="min-w-[10rem] flex-1 space-y-1.5">
                  <label htmlFor={`extra-nome-${campo.id}`} className="text-xs font-semibold text-slate-700">
                    Nome do campo
                  </label>
                  <input
                    id={`extra-nome-${campo.id}`}
                    type="text"
                    maxLength={60}
                    value={campo.nome}
                    disabled={disabled}
                    placeholder="Ex.: Observações do ensaio"
                    className={classeInput}
                    onChange={(e) => alterar(i, { nome: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <label htmlFor={`extra-tipo-${campo.id}`} className="text-xs font-semibold text-slate-700">
                    Tipo
                  </label>
                  <select
                    id={`extra-tipo-${campo.id}`}
                    value={campo.tipo}
                    disabled={disabled}
                    className={cn(classeInput, "w-44")}
                    onChange={(e) => alterar(i, { tipo: e.target.value as TipoCampoExtra })}
                  >
                    {TIPOS_CAMPO.map((t) => (
                      <option key={t} value={t}>
                        {ROTULO_TIPO_CAMPO[t]}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    type="button"
                    title="Subir"
                    aria-label={`Subir ${campo.nome || "campo"}`}
                    disabled={disabled || i === 0}
                    onClick={() => mover(i, -1)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-slate-500 hover:bg-slate-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-30"
                  >
                    <ChevronUp className="h-4 w-4" aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    title="Descer"
                    aria-label={`Descer ${campo.nome || "campo"}`}
                    disabled={disabled || i === campos.length - 1}
                    onClick={() => mover(i, 1)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-slate-500 hover:bg-slate-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-30"
                  >
                    <ChevronDown className="h-4 w-4" aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    title="Excluir campo"
                    aria-label={`Excluir ${campo.nome || "campo"}`}
                    disabled={disabled}
                    onClick={() => trocar(campos.filter((_, k) => k !== i))}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-red-600 hover:bg-red-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-red-300 disabled:opacity-30"
                  >
                    <Trash2 className="h-4 w-4" aria-hidden="true" />
                  </button>
                </div>
              </div>

              {campo.tipo === "lista" && (
                <div className="space-y-1.5">
                  <label htmlFor={`extra-opcoes-${campo.id}`} className="text-xs font-semibold text-slate-700">
                    Opções da lista (uma por linha, no mínimo 2)
                  </label>
                  <textarea
                    id={`extra-opcoes-${campo.id}`}
                    rows={3}
                    value={campo.opcoes.join("\n")}
                    disabled={disabled}
                    placeholder={"Opção 1\nOpção 2"}
                    className={cn(classeInput, "resize-none")}
                    onChange={(e) => alterar(i, { opcoes: e.target.value.split("\n") })}
                  />
                </div>
              )}

              <div className="flex flex-wrap items-center gap-x-5 gap-y-1">
                <label className="flex items-center gap-2 text-sm text-slate-800">
                  <input type="checkbox" checked={campo.obrigatorio} disabled={disabled} className="h-4 w-4" onChange={() => alterar(i, { obrigatorio: !campo.obrigatorio })} />
                  Obrigatório
                </label>
                <label className="flex items-center gap-2 text-sm text-slate-800">
                  <input type="checkbox" checked={campo.ativo} disabled={disabled} className="h-4 w-4" onChange={() => alterar(i, { ativo: !campo.ativo })} />
                  Ativo (aparece na tela)
                </label>
              </div>
            </div>
          ))
        )}
        <p className="text-xs text-slate-500">
          A ordem daqui é a ordem da tela. Campo que já foi preenchido em algum ensaio não pode ser excluído nem mudar de tipo:
          desmarque &quot;Ativo&quot; para escondê-lo.
        </p>
      </div>
    </section>
  );
}
