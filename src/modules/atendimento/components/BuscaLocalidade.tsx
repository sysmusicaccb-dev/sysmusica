"use client";

/**
 * Sysmusica — Casa de Oração de origem (opcional) de quem entra sem cadastro.
 * Busca pelas primeiras letras do nome da casa de oração (a partir de 2 letras). Se houver casas com o mesmo
 * nome em lugares diferentes, a lista mostra o caminho (estado, região, setor) de cada uma para a pessoa escolher.
 * Se a casa não estiver na lista: nome digitado + Estado (UF) + Cidade, com a lista de municípios do IBGE.
 * Sem escolher nada também é permitido.
 */
import { useRef, useState } from "react";
import { buscarLocalidades } from "../services/entrada";
import CampoCidadeUf from "./CampoCidadeUf";
import type { LocalidadeBusca } from "../tiposEntrada";

interface BuscaLocalidadeProps {
  escolhida: LocalidadeBusca | null;
  onEscolher: (localidade: LocalidadeBusca | null) => void;
  outra: boolean;
  onOutra: (valor: boolean) => void;
  texto: string; // nome da casa de oração digitada (fora da lista)
  onTexto: (valor: string) => void;
  uf: string; // estado da casa fora da lista
  onUf: (valor: string) => void;
  cidade: string; // cidade da casa fora da lista (lista oficial do IBGE)
  onCidade: (valor: string) => void;
  desabilitado?: boolean;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

export default function BuscaLocalidade({
  escolhida,
  onEscolher,
  outra,
  onOutra,
  texto,
  onTexto,
  uf,
  onUf,
  cidade,
  onCidade,
  desabilitado = false,
}: BuscaLocalidadeProps) {
  const [termo, setTermo] = useState("");
  const [resultados, setResultados] = useState<LocalidadeBusca[]>([]);
  const [buscando, setBuscando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  const contador = useRef(0); // ignora respostas antigas quando a pessoa continua digitando

  // A busca espera 300 ms depois da última letra para não consultar a cada tecla
  function aoDigitar(valor: string) {
    setTermo(valor);
    setErro(null);
    if (temporizador.current) clearTimeout(temporizador.current);
    const atual = ++contador.current;

    if (valor.trim().length < 2) {
      setResultados([]);
      setBuscando(false);
      return;
    }
    setBuscando(true);
    temporizador.current = setTimeout(() => {
      buscarLocalidades(valor.trim())
        .then((lista) => {
          if (atual === contador.current) setResultados(lista);
        })
        .catch((e: unknown) => {
          if (atual === contador.current) {
            setResultados([]);
            setErro(e instanceof Error ? e.message : "Não foi possível buscar a localidade.");
          }
        })
        .finally(() => {
          if (atual === contador.current) setBuscando(false);
        });
    }, 300);
  }

  function escolher(localidade: LocalidadeBusca) {
    onEscolher(localidade);
    setTermo("");
    setResultados([]);
  }

  // Casas com o mesmo nome (ex.: "Centro" em cidades diferentes): avisa para conferir o caminho antes de escolher
  const nomes = resultados.map((item) => item.nome.trim().toLowerCase());
  const haNomeRepetido = nomes.some((nome, indice) => nomes.indexOf(nome) !== indice);

  return (
    <fieldset className="space-y-3" disabled={desabilitado}>
      <legend className="text-sm font-medium text-slate-700">
        Casa de Oração <span className="font-normal text-slate-500">(opcional)</span>
      </legend>

      {escolhida ? (
        <div className="flex items-start justify-between gap-3 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2">
          <div className="min-w-0 text-sm">
            <p className="font-medium text-emerald-900">{escolhida.nome}</p>
            <p className="text-xs text-emerald-800">{escolhida.caminho}</p>
          </div>
          <button
            type="button"
            onClick={() => onEscolher(null)}
            className="shrink-0 text-xs font-semibold text-emerald-900 hover:underline"
          >
            Trocar
          </button>
        </div>
      ) : (
        !outra && (
          <div className="space-y-2">
            <label htmlFor="busca-localidade" className="sr-only">
              Buscar a casa de oração pelas primeiras letras
            </label>
            <input
              id="busca-localidade"
              type="search"
              autoComplete="off"
              value={termo}
              onChange={(e) => aoDigitar(e.target.value)}
              placeholder="Digite as primeiras letras da casa de oração"
              className={classeInput}
            />
            {termo.trim().length > 0 && termo.trim().length < 2 && (
              <p className="text-xs text-slate-500">Digite pelo menos 2 letras.</p>
            )}
            {buscando && <p className="text-xs text-slate-500">Buscando...</p>}
            {erro && (
              <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">
                {erro}
              </p>
            )}
            {!buscando && !erro && termo.trim().length >= 2 && resultados.length === 0 && (
              <p className="text-xs text-slate-500">Nenhuma casa de oração encontrada. Use &quot;A casa de oração não está na lista&quot;.</p>
            )}
            {haNomeRepetido && (
              <p className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
                Há casas de oração com o mesmo nome em lugares diferentes. Confira o caminho (estado, região e setor)
                abaixo de cada nome antes de escolher.
              </p>
            )}
            {resultados.length > 0 && (
              <ul className="max-h-56 divide-y divide-slate-100 overflow-y-auto rounded-lg border border-slate-200">
                {resultados.map((item) => (
                  <li key={item.casa_oracao_id}>
                    <button
                      type="button"
                      onClick={() => escolher(item)}
                      className="block w-full px-3 py-2 text-left transition hover:bg-slate-50"
                    >
                      <span className="block text-sm font-medium text-slate-900">{item.nome}</span>
                      <span className="block text-xs text-slate-500">{item.caminho}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )
      )}

      {!escolhida && (
        <label className="flex items-start gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={outra}
            onChange={(e) => onOutra(e.target.checked)}
            className="mt-0.5 h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
          />
          A casa de oração não está na lista
        </label>
      )}

      {outra && !escolhida && (
        <div className="space-y-3">
          <div className="space-y-1.5">
            <label htmlFor="localidade-outra" className="text-xs font-medium text-slate-600">
              Nome da Casa de Oração
            </label>
            <input
              id="localidade-outra"
              type="text"
              maxLength={70}
              value={texto}
              onChange={(e) => onTexto(e.target.value)}
              placeholder="Ex.: Centro"
              className={classeInput}
            />
          </div>
          {/* Estado e cidade: a lista de cidades vem do IBGE (busca online) */}
          <CampoCidadeUf idBase="localidade-outra" uf={uf} onUf={onUf} cidade={cidade} onCidade={onCidade} />
        </div>
      )}
    </fieldset>
  );
}
