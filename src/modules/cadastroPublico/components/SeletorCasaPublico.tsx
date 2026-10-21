"use client";

/**
 * SysMúsica — Escolha da Casa de Oração no formulário público.
 * A lista vem da função pública opcoes_cadastro_publico (só nome e caminho na organização: RRM › RA › ADM › Setor).
 * Há uma busca por texto para achar a casa sem rolar a lista inteira.
 */
import { useMemo, useState } from "react";
import type { CasaPublica } from "../regras";
import { classeInput } from "./Campos";

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function caminho(casa: CasaPublica): string {
  return [casa.rrm, casa.ra, casa.adm, casa.setor].filter((parte): parte is string => !!parte).join(" › ");
}

interface Props {
  id: string;
  valor: string;
  onChange: (id: string) => void;
  casas: CasaPublica[];
  disabled?: boolean;
}

export default function SeletorCasaPublico({ id, valor, onChange, casas, disabled }: Props) {
  const [busca, setBusca] = useState("");

  const filtradas = useMemo(() => {
    const termo = semAcento(busca.trim());
    const lista = termo === "" ? casas : casas.filter((c) => semAcento(`${c.nome} ${caminho(c)}`).includes(termo));
    // A casa já escolhida nunca some da lista, mesmo que a busca mude
    const escolhida = casas.find((c) => c.id === valor);
    return escolhida && !lista.some((c) => c.id === valor) ? [escolhida, ...lista] : lista;
  }, [busca, casas, valor]);

  return (
    <div className="space-y-2">
      <input
        type="search"
        value={busca}
        onChange={(e) => setBusca(e.target.value)}
        disabled={disabled}
        placeholder="Digite parte do nome da Casa de Oração para filtrar"
        aria-label="Filtrar Casas de Oração"
        className={classeInput}
      />
      <select id={id} value={valor} onChange={(e) => onChange(e.target.value)} required disabled={disabled} className={classeInput}>
        <option value="">Selecione a Casa de Oração</option>
        {filtradas.map((casa) => (
          <option key={casa.id} value={casa.id}>
            {casa.nome}
            {caminho(casa) ? ` — ${caminho(casa)}` : ""}
          </option>
        ))}
      </select>
    </div>
  );
}
