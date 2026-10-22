"use client";

/**
 * Sysmusica — Seletor de instrumento (lista suspensa agrupada por FAMÍLIA) e campo "Família (automática)".
 * É o único jeito de escolher instrumento no sistema (cadastro de membro e de visitante), igual aos
 * demais seletores (Cargo, Casa de Oração). Só aparecem os instrumentos cadastrados no banco; instrumento novo
 * se cadastra em Instrumentos e famílias, onde a família também é definida.
 */
import { useMemo } from "react";
import {
  agruparInstrumentosPorFamilia,
  nomeDaFamiliaDoInstrumento,
  type FamiliaOpcao,
  type InstrumentoOpcao,
} from "../selecao";

interface SeletorInstrumentoProps {
  id?: string;
  valor: string; // id do instrumento escolhido ("" = nenhum)
  onChange: (instrumentoId: string) => void;
  instrumentos: InstrumentoOpcao[];
  familias: FamiliaOpcao[];
  obrigatorio?: boolean;
  disabled?: boolean;
  className?: string;
}

export default function SeletorInstrumento({
  id,
  valor,
  onChange,
  instrumentos,
  familias,
  obrigatorio,
  disabled,
  className,
}: SeletorInstrumentoProps) {
  const grupos = useMemo(() => agruparInstrumentosPorFamilia(instrumentos, familias), [instrumentos, familias]);

  return (
    <select
      id={id}
      value={valor}
      onChange={(e) => onChange(e.target.value)}
      required={obrigatorio}
      disabled={disabled}
      className={className}
    >
      <option value="">{obrigatorio ? "Selecione o instrumento" : "Sem instrumento / não informado"}</option>
      {grupos.map((grupo) => (
        <optgroup key={grupo.familiaId ?? "sem-familia"} label={grupo.rotulo}>
          {grupo.instrumentos.map((instrumento) => (
            <option key={instrumento.id} value={instrumento.id}>
              {instrumento.nome}
            </option>
          ))}
        </optgroup>
      ))}
    </select>
  );
}

interface FamiliaAutomaticaProps {
  instrumentoId: string;
  instrumentos: InstrumentoOpcao[];
  familias: FamiliaOpcao[];
}

/** Campo somente leitura: a família sai do instrumento escolhido (cadastro do banco). */
export function FamiliaAutomatica({ instrumentoId, instrumentos, familias }: FamiliaAutomaticaProps) {
  const escolhido = instrumentoId !== "" && instrumentos.some((instrumento) => instrumento.id === instrumentoId);
  const nome = nomeDaFamiliaDoInstrumento(instrumentoId, instrumentos, familias);
  const texto = !escolhido ? "" : (nome ?? "Sem família definida (classifique em Instrumentos e famílias)");

  return (
    <div className="space-y-1.5">
      <label htmlFor="familia-instrumento" className="text-sm font-medium text-slate-700">
        Família <span className="font-normal text-slate-400">(automática)</span>
      </label>
      <input
        id="familia-instrumento"
        type="text"
        readOnly
        tabIndex={-1}
        value={texto}
        placeholder="Definida automaticamente pelo instrumento"
        className="w-full cursor-default rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none"
      />
    </div>
  );
}
