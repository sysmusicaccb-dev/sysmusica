"use client";

/**
 * Sysmusica — Formulário de preenchimento das fichas M02, M03 e M05 (dentro do painel lateral).
 * A pessoa é escolhida no cadastro (busca por nome): nome, Casa de Oração e instrumento já vêm preenchidos,
 * mas podem ser ajustados para o papel. O painel só monta este componente quando está aberto, então ele
 * sempre começa limpo (ou com a ficha que está sendo editada).
 */
import { useRef, useState } from "react";
import { DESTINOS_M05, dadosIniciais, lerDados, validarFicha, type DadosFicha, type DestinoOrganista } from "../dados";
import { buscarMembrosParaFicha, salvarFicha, type FichaCompleta, type MembroBusca } from "../services/fichas";
import type { TipoFicha } from "../tipos";

interface FormularioFichaProps {
  tipo: TipoFicha;
  ficha: FichaCompleta | null; // ficha em edição (nula = nova)
  onSalvo: (mensagem: string) => void;
  onCancelar: () => void;
}

const CLASSE_CAMPO =
  "mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function FormularioFicha({ tipo, ficha, onSalvo, onCancelar }: FormularioFichaProps) {
  const [membroId, setMembroId] = useState<string | null>(ficha?.membro_id ?? null);
  const [dados, setDados] = useState<DadosFicha>(() => (ficha ? lerDados(ficha.dados) : dadosIniciais()));
  const [termo, setTermo] = useState("");
  const [achados, setAchados] = useState<MembroBusca[]>([]);
  const [buscando, setBuscando] = useState(false);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  const organista = tipo === "M05";

  function alterar<K extends keyof DadosFicha>(chave: K, valor: DadosFicha[K]) {
    setDados((atual) => ({ ...atual, [chave]: valor }));
  }

  // Busca no cadastro com pequena espera, para não consultar a cada letra
  function aoDigitarBusca(texto: string) {
    setTermo(texto);
    if (temporizador.current) clearTimeout(temporizador.current);
    if (texto.trim().length < 2) {
      setAchados([]);
      return;
    }
    temporizador.current = setTimeout(async () => {
      setBuscando(true);
      try {
        setAchados(await buscarMembrosParaFicha(texto));
        setErro(null);
      } catch (e) {
        setErro(e instanceof Error ? e.message : "Não foi possível buscar no cadastro.");
      } finally {
        setBuscando(false);
      }
    }, 350);
  }

  // Ao escolher a pessoa, puxa nome, Casa de Oração e instrumento do cadastro
  function escolher(m: MembroBusca) {
    setMembroId(m.id);
    setDados((atual) => ({
      ...atual,
      nome: m.nome,
      comum: m.casa_nome ?? atual.comum,
      instrumento: organista ? atual.instrumento : (m.instrumento_nome ?? atual.instrumento),
    }));
    setAchados([]);
    setTermo("");
  }

  async function salvar() {
    const problema = validarFicha(tipo, membroId, dados);
    if (problema) {
      setErro(problema);
      return;
    }
    setSalvando(true);
    setErro(null);
    try {
      await salvarFicha(ficha?.id ?? null, tipo, membroId as string, dados);
      onSalvo(ficha ? "Ficha alterada." : "Ficha salva.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar a ficha.");
      setSalvando(false);
    }
  }

  return (
    <form
      className="space-y-4"
      onSubmit={(ev) => {
        ev.preventDefault();
        void salvar();
      }}
    >
      <div>
        <label htmlFor="ficha-busca" className="text-sm font-medium text-slate-700">Pessoa do cadastro</label>
        <input id="ficha-busca" type="search" value={termo} onChange={(ev) => aoDigitarBusca(ev.target.value)} placeholder="Digite parte do nome (mínimo 2 letras)" className={CLASSE_CAMPO} autoComplete="off" />
        {buscando && <p className="mt-1 text-xs text-slate-500">Buscando...</p>}
        {achados.length > 0 && (
          <ul className="mt-1 max-h-48 overflow-y-auto rounded-lg border border-slate-200 bg-white text-sm shadow-sm">
            {achados.map((m) => (
              <li key={m.id}>
                <button type="button" onClick={() => escolher(m)} className="block w-full px-3 py-2 text-left hover:bg-slate-50">
                  <span className="font-medium">{m.nome}</span>
                  <span className="ml-2 text-xs text-slate-500">{[m.casa_nome, m.instrumento_nome].filter(Boolean).join(" · ")}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
        {membroId ? (
          <p className="mt-1 text-xs text-emerald-700">Pessoa escolhida: {dados.nome}</p>
        ) : (
          <p className="mt-1 text-xs text-slate-500">Escolha a pessoa para ligar a ficha ao cadastro (é isso que permite mudar a categoria quando for Apto).</p>
        )}
      </div>

      <div>
        <label htmlFor="ficha-nome" className="text-sm font-medium text-slate-700">Nome completo (sem abreviações)</label>
        <input id="ficha-nome" value={dados.nome} onChange={(ev) => alterar("nome", ev.target.value)} className={CLASSE_CAMPO} />
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label htmlFor="ficha-comum" className="text-sm font-medium text-slate-700">Comum Congregação</label>
          <input id="ficha-comum" value={dados.comum} onChange={(ev) => alterar("comum", ev.target.value)} className={CLASSE_CAMPO} />
        </div>
        {!organista && (
          <div>
            <label htmlFor="ficha-instrumento" className="text-sm font-medium text-slate-700">Instrumento e tonalidade</label>
            <input id="ficha-instrumento" value={dados.instrumento} onChange={(ev) => alterar("instrumento", ev.target.value)} placeholder="Ex.: Trompete em Si bemol" className={CLASSE_CAMPO} />
          </div>
        )}
      </div>

      {organista && (
        <>
          <fieldset>
            <legend className="text-sm font-medium text-slate-700">Solicitamos a avaliação desta irmã para</legend>
            <div className="mt-1 flex flex-wrap gap-4">
              {DESTINOS_M05.map((d) => (
                <label key={d.valor} className="flex items-center gap-2 text-sm">
                  <input type="radio" name="ficha-para" checked={dados.para === d.valor} onChange={() => alterar("para", d.valor as DestinoOrganista)} />
                  {d.rotulo}
                </label>
              ))}
            </div>
          </fieldset>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label htmlFor="ficha-prof" className="text-sm font-medium text-slate-700">Professora (nome completo)</label>
              <input id="ficha-prof" value={dados.professora_nome} onChange={(ev) => alterar("professora_nome", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
            <div>
              <label htmlFor="ficha-prof-comum" className="text-sm font-medium text-slate-700">Comum Congregação da professora</label>
              <input id="ficha-prof-comum" value={dados.professora_comum} onChange={(ev) => alterar("professora_comum", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
          </div>
        </>
      )}

      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label htmlFor="ficha-local" className="text-sm font-medium text-slate-700">Cidade (localidade)</label>
          <input id="ficha-local" value={dados.local} onChange={(ev) => alterar("local", ev.target.value)} className={CLASSE_CAMPO} />
        </div>
        <div>
          <label htmlFor="ficha-data" className="text-sm font-medium text-slate-700">Data do pedido</label>
          <input id="ficha-data" type="date" value={dados.data} onChange={(ev) => alterar("data", ev.target.value)} className={CLASSE_CAMPO} />
        </div>
      </div>

      {erro && <p role="alert" className="text-sm text-red-600">{erro}</p>}
      <div className="flex justify-end gap-2 pt-2">
        <button type="button" onClick={onCancelar} className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">Cancelar</button>
        <button type="submit" disabled={salvando} className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-700 disabled:opacity-60">
          {salvando ? "Salvando..." : "Salvar ficha"}
        </button>
      </div>
    </form>
  );
}
