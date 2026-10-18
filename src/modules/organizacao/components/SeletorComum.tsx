"use client";

/**
 * SysMúsica — Seletor de COMUM (igreja/salão), agrupado por "Região › Setor".
 * Mostra só as comuns que o usuário pode usar (o banco filtra pela abrangência dele; quem tem
 * acesso total vê todas). Usado nos eventos e, em seguida, no cadastro de membros.
 */
import { useEffect, useMemo, useState } from "react";
import { agruparComunsParaSelecao } from "../regras";
import { listarOrganizacaoParaSelecao } from "../services/organizacao";
import type { NoOrganizacao } from "../tipos";

interface SeletorComumProps {
  id?: string;
  valor: string; // id da comum escolhida ("" = nenhuma)
  onChange: (comumId: string) => void;
  disabled?: boolean;
  className?: string;
}

export default function SeletorComum({ id, valor, onChange, disabled, className }: SeletorComumProps) {
  const [nos, setNos] = useState<NoOrganizacao[] | null>(null); // nulo = ainda carregando
  const [erro, setErro] = useState<string | null>(null);

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    let cancelado = false;
    void listarOrganizacaoParaSelecao()
      .then((lista) => {
        if (!cancelado) setNos(lista);
      })
      .catch((e: unknown) => {
        if (cancelado) return;
        setNos([]);
        setErro(e instanceof Error ? e.message : "Não foi possível carregar as comuns.");
      });
    return () => {
      cancelado = true;
    };
  }, []);
  /* eslint-enable react-hooks/set-state-in-effect */

  const grupos = useMemo(() => agruparComunsParaSelecao(nos ?? []), [nos]);
  const existe = grupos.some((grupo) => grupo.comuns.some((comum) => comum.id === valor));

  return (
    <>
      <select
        id={id}
        value={valor}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled || nos === null}
        className={className}
      >
        <option value="">{nos === null ? "Carregando..." : "Nenhuma (definir depois)"}</option>
        {/* A comum atual do registro pode estar fora da abrangência de quem edita: continua visível, sem trocar sozinha */}
        {nos !== null && valor !== "" && !existe && <option value={valor}>Comum atual (fora da sua abrangência)</option>}
        {grupos.map((grupo) => (
          <optgroup key={grupo.rotulo} label={grupo.rotulo}>
            {grupo.comuns.map((comum) => (
              <option key={comum.id} value={comum.id}>
                {comum.nome}
              </option>
            ))}
          </optgroup>
        ))}
      </select>
      {erro && (
        <p role="alert" className="mt-1 text-xs text-red-700">
          {erro}
        </p>
      )}
    </>
  );
}
