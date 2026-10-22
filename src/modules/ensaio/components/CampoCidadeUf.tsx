"use client";

/**
 * Sysmusica — Campo "Cidade-UF" com sugestões do IBGE.
 * Ao digitar ("sao pau"), aparece a lista de municípios; ao escolher, o texto vira "São Paulo-SP".
 * Se o IBGE estiver fora do ar a lista fica vazia e a pessoa digita à mão no formato Cidade-UF (o banco confere).
 */
import { useState } from "react";
import { buscarCidades, rotuloDaCidade, type Cidade } from "../cidades";

interface CampoCidadeUfProps {
  id: string;
  valor: string;
  onChange: (valor: string) => void;
  cidades: Cidade[];
  disabled?: boolean;
  invalido?: boolean;
}

const classeInput =
  "w-full rounded-lg border bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm " +
  "focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-60 ";

export default function CampoCidadeUf({ id, valor, onChange, cidades, disabled, invalido }: CampoCidadeUfProps) {
  const [aberto, setAberto] = useState(false);
  const [ativa, setAtiva] = useState(-1);
  const sugestoes = aberto ? buscarCidades(cidades, valor) : [];
  const idLista = `${id}-sugestoes`;

  function escolher(cidade: Cidade) {
    onChange(rotuloDaCidade(cidade));
    setAberto(false);
    setAtiva(-1);
  }

  return (
    <div className="relative">
      <input
        id={id}
        type="text"
        role="combobox"
        aria-expanded={sugestoes.length > 0}
        aria-controls={idLista}
        aria-autocomplete="list"
        aria-invalid={invalido || undefined}
        autoComplete="off"
        value={valor}
        disabled={disabled}
        placeholder="Digite a cidade (ex: São Paulo-SP)"
        onChange={(e) => {
          onChange(e.target.value);
          setAberto(true);
          setAtiva(-1);
        }}
        onFocus={() => setAberto(true)}
        onBlur={() => setAberto(false)}
        onKeyDown={(e) => {
          if (sugestoes.length === 0) return;
          if (e.key === "ArrowDown") {
            e.preventDefault();
            setAtiva((i) => Math.min(i + 1, sugestoes.length - 1));
          } else if (e.key === "ArrowUp") {
            e.preventDefault();
            setAtiva((i) => Math.max(i - 1, 0));
          } else if (e.key === "Enter" && ativa >= 0) {
            e.preventDefault(); // não envia o formulário: só escolhe a sugestão
            escolher(sugestoes[ativa]);
          } else if (e.key === "Escape") {
            setAberto(false);
          }
        }}
        className={classeInput + (invalido ? "border-red-400 focus:ring-red-200" : "border-slate-300 focus:border-brand-500 focus:ring-brand-200")}
      />
      {sugestoes.length > 0 && (
        <ul
          id={idLista}
          role="listbox"
          className="absolute z-20 mt-1 max-h-56 w-full overflow-y-auto rounded-lg border border-slate-200 bg-white py-1 text-sm shadow-lg"
        >
          {sugestoes.map((cidade, indice) => (
            <li
              key={rotuloDaCidade(cidade)}
              role="option"
              aria-selected={indice === ativa}
              // mouseDown (e não click): acontece antes do onBlur do campo, senão a lista fecharia antes de escolher
              onMouseDown={(e) => {
                e.preventDefault();
                escolher(cidade);
              }}
              className={"cursor-pointer px-3 py-1.5 " + (indice === ativa ? "bg-brand-50 text-brand-800" : "hover:bg-slate-50")}
            >
              {rotuloDaCidade(cidade)}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
