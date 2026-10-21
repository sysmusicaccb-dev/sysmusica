"use client";

/**
 * SysMúsica — Estado (UF) + Cidade com busca online na lista de municípios do IBGE.
 * Escolhida a UF, a lista de cidades do estado é buscada no IBGE e a cidade é digitada com sugestões.
 * Ao sair do campo, o nome vira o nome OFICIAL do município (sem erro de acento); se não existir na lista,
 * o campo é limpo. Se o IBGE estiver fora do ar, a cidade pode ser digitada à mão (com aviso).
 * Reutilizável (ex.: encarregados do ensaio).
 */
import { useRef, useState } from "react";
import { UFS_BRASIL, acharMunicipio, listarMunicipios } from "@/lib/municipios";

interface CampoCidadeUfProps {
  idBase: string; // prefixo dos ids dos campos
  uf: string;
  onUf: (valor: string) => void;
  cidade: string;
  onCidade: (valor: string) => void;
  desabilitado?: boolean;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

type Situacao = "sem-uf" | "carregando" | "pronta" | "indisponivel";

export default function CampoCidadeUf({ idBase, uf, onUf, cidade, onCidade, desabilitado = false }: CampoCidadeUfProps) {
  const [municipios, setMunicipios] = useState<string[]>([]);
  const [situacao, setSituacao] = useState<Situacao>(uf ? "indisponivel" : "sem-uf");
  const pedido = useRef(0); // ignora respostas de um estado que a pessoa já trocou

  // A lista é buscada no momento em que a UF muda (evento do usuário, não efeito)
  async function trocarUf(sigla: string) {
    onUf(sigla);
    onCidade("");
    setMunicipios([]);
    const atual = ++pedido.current;
    if (!sigla) return setSituacao("sem-uf");
    setSituacao("carregando");
    try {
      const lista = await listarMunicipios(sigla);
      if (atual !== pedido.current) return;
      setMunicipios(lista);
      setSituacao("pronta");
    } catch {
      if (atual === pedido.current) setSituacao("indisponivel");
    }
  }

  // Ao sair do campo: usa o nome oficial; se não existir na lista, limpa
  function conferirCidade() {
    if (situacao !== "pronta" || cidade.trim() === "") return;
    onCidade(acharMunicipio(municipios, cidade) ?? "");
  }

  const listaId = `${idBase}-municipios`;

  return (
    <div className="grid grid-cols-3 gap-3">
      <div className="space-y-1.5">
        <label htmlFor={`${idBase}-uf`} className="text-xs font-medium text-slate-600">
          Estado
        </label>
        <select
          id={`${idBase}-uf`}
          value={uf}
          onChange={(e) => void trocarUf(e.target.value)}
          disabled={desabilitado}
          className={classeInput}
        >
          <option value="">UF</option>
          {UFS_BRASIL.map((sigla) => (
            <option key={sigla} value={sigla}>
              {sigla}
            </option>
          ))}
        </select>
      </div>

      <div className="col-span-2 space-y-1.5">
        <label htmlFor={`${idBase}-cidade`} className="text-xs font-medium text-slate-600">
          Cidade
        </label>
        <input
          id={`${idBase}-cidade`}
          type="text"
          list={listaId}
          autoComplete="off"
          maxLength={60}
          value={cidade}
          onChange={(e) => onCidade(e.target.value)}
          onBlur={conferirCidade}
          disabled={desabilitado || situacao === "sem-uf" || situacao === "carregando"}
          placeholder={
            situacao === "sem-uf" ? "Escolha o estado primeiro" : situacao === "carregando" ? "Buscando cidades..." : "Digite a cidade"
          }
          className={classeInput}
        />
        <datalist id={listaId}>
          {municipios.map((nome) => (
            <option key={nome} value={nome} />
          ))}
        </datalist>
      </div>

      {situacao === "indisponivel" && uf && (
        <p className="col-span-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
          Não foi possível buscar a lista de cidades online agora. Digite o nome da cidade.
        </p>
      )}
    </div>
  );
}
