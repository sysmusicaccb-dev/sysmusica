"use client";

/**
 * Sysmusica — Pergunta "Vai tocar?" (Sim / Não) e, quando for tocar, a escolha do instrumento.
 * Usada na conferência do membro cadastrado e na entrada sem cadastro.
 * Se o membro já tem instrumento no cadastro, ele aparece como sugestão e a Portaria só troca se for outro.
 */
import { agruparInstrumentos } from "../regrasEntrada";
import type { InstrumentoEntrada } from "../tiposEntrada";

interface PerguntaTocaProps {
  /** Mostra a pergunta "Vai tocar?" (as linhas que sempre tocam só pedem o instrumento). */
  perguntar: boolean;
  /** Mostra o campo do instrumento (quando vai tocar ou quando a linha sempre toca). */
  pedirInstrumento: boolean;
  toca: boolean | null;
  onToca: (valor: boolean) => void;
  instrumentoId: string;
  onInstrumento: (id: string) => void;
  instrumentos: InstrumentoEntrada[];
  /** Instrumento já cadastrado do membro (sugestão), se houver. */
  instrumentoCadastro?: string | null;
  desabilitado?: boolean;
  /** Prefixo para os ids dos campos (a tela pode ter mais de uma pergunta). */
  prefixo: string;
}

export default function PerguntaToca({
  perguntar,
  pedirInstrumento,
  toca,
  onToca,
  instrumentoId,
  onInstrumento,
  instrumentos,
  instrumentoCadastro = null,
  desabilitado = false,
  prefixo,
}: PerguntaTocaProps) {
  const grupos = agruparInstrumentos(instrumentos);

  return (
    <div className="space-y-3">
      {perguntar && (
        <fieldset disabled={desabilitado} className="space-y-2">
          <legend className="text-sm font-medium text-slate-700">Vai tocar?</legend>
          <div className="grid grid-cols-2 gap-2">
            {[
              { valor: true, rotulo: "Sim, vai tocar" },
              { valor: false, rotulo: "Não vai tocar" },
            ].map((opcao) => (
              <label
                key={String(opcao.valor)}
                className={
                  "flex cursor-pointer items-center justify-center rounded-lg border px-3 py-3 text-sm font-medium transition " +
                  (toca === opcao.valor
                    ? "border-brand-600 bg-brand-50 text-brand-700"
                    : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50")
                }
              >
                <input
                  type="radio"
                  name={`${prefixo}-toca`}
                  checked={toca === opcao.valor}
                  onChange={() => onToca(opcao.valor)}
                  className="sr-only"
                />
                {opcao.rotulo}
              </label>
            ))}
          </div>
        </fieldset>
      )}

      {pedirInstrumento && (
        <div className="space-y-1.5">
          <label htmlFor={`${prefixo}-instrumento`} className="text-sm font-medium text-slate-700">
            Instrumento
            {instrumentoCadastro ? (
              <span className="font-normal text-slate-500"> (no cadastro: {instrumentoCadastro})</span>
            ) : null}
          </label>
          <select
            id={`${prefixo}-instrumento`}
            value={instrumentoId}
            onChange={(e) => onInstrumento(e.target.value)}
            disabled={desabilitado}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
          >
            <option value="">
              {instrumentoCadastro ? `Usar o do cadastro (${instrumentoCadastro})` : "Selecione o instrumento"}
            </option>
            {grupos.map((grupo) => (
              <optgroup key={grupo.familia} label={grupo.familia}>
                {grupo.itens.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.nome}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </div>
      )}
    </div>
  );
}
