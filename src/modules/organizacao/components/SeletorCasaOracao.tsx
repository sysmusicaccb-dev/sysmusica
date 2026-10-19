"use client";

/**
 * SysMúsica — Seletor de CASA DE ORAÇÃO (igreja/salão), agrupado por "Região › Setor".
 * Mostra só as casas de oração que o usuário pode usar (o banco filtra pela abrangência dele; quem tem
 * acesso total vê todas). Usado nos eventos e, em seguida, no cadastro de membros.
 */
import { useEffect, useMemo, useState } from "react";
import { agruparCasasOracaoParaSelecao } from "../regras";
import { listarOrganizacaoParaSelecao } from "../services/organizacao";
import type { NoOrganizacao } from "../tipos";

interface SeletorCasaOracaoProps {
  id?: string;
  valor: string; // id da casa de oração escolhida ("" = nenhuma)
  onChange: (casaOracaoId: string) => void;
  /** Opcional: devolve também o nome da casa de oração escolhida (vazio quando nenhuma). */
  onEscolherNome?: (nome: string) => void;
  disabled?: boolean;
  className?: string;
}

export default function SeletorCasaOracao({
  id,
  valor,
  onChange,
  onEscolherNome,
  disabled,
  className,
}: SeletorCasaOracaoProps) {
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
        setErro(e instanceof Error ? e.message : "Não foi possível carregar as casas de oração.");
      });
    return () => {
      cancelado = true;
    };
  }, []);
  /* eslint-enable react-hooks/set-state-in-effect */

  const grupos = useMemo(() => agruparCasasOracaoParaSelecao(nos ?? []), [nos]);
  const existe = grupos.some((grupo) => grupo.casasOracao.some((casaOracao) => casaOracao.id === valor));

  return (
    <>
      <select
        id={id}
        value={valor}
        onChange={(e) => {
          const novoId = e.target.value;
          onChange(novoId);
          onEscolherNome?.((nos ?? []).find((no) => no.nivel === "CASA_ORACAO" && no.id === novoId)?.nome ?? "");
        }}
        disabled={disabled || nos === null}
        className={className}
      >
        <option value="">{nos === null ? "Carregando..." : "Nenhuma (definir depois)"}</option>
        {/* A casa de oração atual do registro pode estar fora da abrangência de quem edita: continua visível, sem trocar sozinha */}
        {nos !== null && valor !== "" && !existe && <option value={valor}>Casa de Oração atual (fora da sua abrangência)</option>}
        {grupos.map((grupo) => (
          <optgroup key={grupo.rotulo} label={grupo.rotulo}>
            {grupo.casasOracao.map((casaOracao) => (
              <option key={casaOracao.id} value={casaOracao.id}>
                {casaOracao.nome}
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
