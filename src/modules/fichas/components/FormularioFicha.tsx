"use client";

/**
 * Sysmusica — Formulário de preenchimento das fichas M01, M02, M03, M05, M07 e Avaliação RJM (dentro do painel lateral).
 * A pessoa é escolhida no cadastro (busca por nome): nome, Casa de Oração e instrumento já vêm preenchidos,
 * mas podem ser ajustados para o papel. O painel só monta este componente quando está aberto, então ele
 * sempre começa limpo (ou com a ficha que está sendo editada).
 */
import { useEffect, useRef, useState } from "react";
import { buscarInstrumentosEFamilias } from "@/modules/instrumentos/services/instrumentos";
import { DESTINOS_M05, MOTIVOS_M07, dadosIniciais, lerDados, preencherDoCadastro, validarFicha, type DadosFicha, type DestinoOrganista } from "../dados";
import { obterDadosDoMembro } from "../services/cadastro";
import { buscarMembrosParaFicha, salvarFicha, type FichaCompleta, type MembroBusca } from "../services/fichas";
import type { TipoFicha } from "../tipos";

interface FormularioFichaProps {
  tipo: TipoFicha;
  ficha: FichaCompleta | null; // ficha em edição (nula = nova)
  paraInicial?: DestinoOrganista; // M05 nova: destino já marcado pela guia (Organistas > etapa)
  onSalvo: (mensagem: string) => void;
  onCancelar: () => void;
}

const CLASSE_CAMPO =
  "mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function FormularioFicha({ tipo, ficha, paraInicial, onSalvo, onCancelar }: FormularioFichaProps) {
  const [membroId, setMembroId] = useState<string | null>(ficha?.membro_id ?? null);
  const [dados, setDados] = useState<DadosFicha>(() => (ficha ? lerDados(ficha.dados) : { ...dadosIniciais(), para: paraInicial ?? "" }));
  const [termo, setTermo] = useState("");
  const [achados, setAchados] = useState<MembroBusca[]>([]);
  const [buscando, setBuscando] = useState(false);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  const organista = tipo === "M05";
  const ingresso = tipo === "M01"; // M01 (GEM) tem campos próprios e não tem cidade/data do pedido
  const troca = tipo === "M07"; // M07 (troca de instrumento) escolhe o instrumento novo
  const [instrumentos, setInstrumentos] = useState<{ id: string; nome: string }[]>([]);

  // M07: carrega a lista de instrumentos para escolher o novo (o setState roda só depois do await)
  useEffect(() => {
    if (!troca) return;
    let ativo = true;
    buscarInstrumentosEFamilias()
      .then((r) => {
        if (ativo) setInstrumentos(r.instrumentos.map((i) => ({ id: i.id, nome: i.nome })));
      })
      .catch(() => {
        if (ativo) setErro("Não foi possível carregar a lista de instrumentos.");
      });
    return () => {
      ativo = false;
    };
  }, [troca]);

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
        setAchados(await buscarMembrosParaFicha(texto, tipo, dados.para || null));
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
      instrumento_atual: m.instrumento_nome ?? atual.instrumento_atual, // M07
    }));
    setAchados([]);
    setTermo("");
    // Puxa do cadastro tudo o que a ficha usa (estado civil, telefone, nascimento...). Se falhar, a pessoa preenche na mão.
    void obterDadosDoMembro(m.id)
      .then((cadastro) => setDados((atual) => preencherDoCadastro(tipo, atual, cadastro)))
      .catch(() => undefined);
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
                {/* Quem não pode entrar nesta ficha (trava de etapa) aparece, mas não pode ser escolhido */}
                <button type="button" disabled={Boolean(m.motivo)} onClick={() => escolher(m)} className="block w-full px-3 py-2 text-left hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-70">
                  <span className="font-medium">{m.nome}</span>
                  <span className="ml-2 text-xs text-slate-500">{[m.casa_nome, m.instrumento_nome].filter(Boolean).join(" · ")}</span>
                  {m.motivo && <span className="mt-0.5 block text-xs text-red-600">Não pode: {m.motivo}</span>}
                </button>
              </li>
            ))}
          </ul>
        )}
        {membroId ? (
          <p className="mt-1 text-xs text-emerald-700">Pessoa escolhida: {dados.nome}</p>
        ) : (
          <p className="mt-1 text-xs text-slate-500">Obrigatório: a ficha só pode ser preenchida para quem já está no cadastro do sistema (candidato, músico ou organista). O nome vem de lá.</p>
        )}
      </div>

      {/* O nome vem do cadastro (pessoa escolhida acima); não se digita aqui */}
      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label htmlFor="ficha-comum" className="text-sm font-medium text-slate-700">Comum Congregação</label>
          <input id="ficha-comum" value={dados.comum} onChange={(ev) => alterar("comum", ev.target.value)} className={CLASSE_CAMPO} />
        </div>
        {!organista && !troca && (
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

      {ingresso && (
        <>
          <div className="grid gap-3 sm:grid-cols-3">
            <div>
              <label htmlFor="ficha-nasc" className="text-sm font-medium text-slate-700">Data de nascimento</label>
              <input id="ficha-nasc" type="date" value={dados.nascimento} onChange={(ev) => alterar("nascimento", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
            <div>
              <label htmlFor="ficha-civil" className="text-sm font-medium text-slate-700">Estado civil</label>
              <input id="ficha-civil" value={dados.estado_civil} onChange={(ev) => alterar("estado_civil", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
            <div>
              <label htmlFor="ficha-tel" className="text-sm font-medium text-slate-700">Telefone / Celular</label>
              <input id="ficha-tel" value={dados.telefone} onChange={(ev) => alterar("telefone", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
          </div>
          <div>
            <label htmlFor="ficha-inicio" className="text-sm font-medium text-slate-700">Data de início no GEM</label>
            <input id="ficha-inicio" type="date" value={dados.inicio_gem} onChange={(ev) => alterar("inicio_gem", ev.target.value)} className={CLASSE_CAMPO} />
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label htmlFor="ficha-resp" className="text-sm font-medium text-slate-700">Responsável (só para menores de 18 anos)</label>
              <input id="ficha-resp" value={dados.responsavel_nome} onChange={(ev) => alterar("responsavel_nome", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
            <div>
              <label htmlFor="ficha-parent" className="text-sm font-medium text-slate-700">Grau de parentesco</label>
              <input id="ficha-parent" value={dados.parentesco} onChange={(ev) => alterar("parentesco", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
          </div>
        </>
      )}

      {troca && (
        <>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label htmlFor="ficha-ofic" className="text-sm font-medium text-slate-700">Data da oficialização</label>
              <input id="ficha-ofic" type="date" value={dados.data_oficializacao} onChange={(ev) => alterar("data_oficializacao", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
            <div>
              <label htmlFor="ficha-atual" className="text-sm font-medium text-slate-700">Instrumento e tonalidade atual</label>
              <input id="ficha-atual" value={dados.instrumento_atual} onChange={(ev) => alterar("instrumento_atual", ev.target.value)} className={CLASSE_CAMPO} />
            </div>
          </div>
          <div>
            <label htmlFor="ficha-novo" className="text-sm font-medium text-slate-700">Instrumento que deseja tocar</label>
            <select
              id="ficha-novo"
              value={dados.instrumento_novo_id}
              onChange={(ev) => {
                const achado = instrumentos.find((i) => i.id === ev.target.value);
                setDados((atual) => ({ ...atual, instrumento_novo_id: ev.target.value, instrumento_novo: achado?.nome ?? "" }));
              }}
              className={CLASSE_CAMPO}
            >
              <option value="">Selecione...</option>
              {instrumentos.map((i) => (
                <option key={i.id} value={i.id}>{i.nome}</option>
              ))}
            </select>
            <p className="mt-1 text-xs text-slate-500">Quando o resultado for Apto, o instrumento do cadastro passa a ser este.</p>
          </div>
          <fieldset>
            <legend className="text-sm font-medium text-slate-700">Motivo da troca</legend>
            <div className="mt-1 flex flex-wrap gap-4">
              {MOTIVOS_M07.map((m) => (
                <label key={m.valor} className="flex items-center gap-2 text-sm">
                  <input type="radio" name="ficha-motivo" checked={dados.motivo === m.valor} onChange={() => alterar("motivo", m.valor)} />
                  {m.rotulo}
                </label>
              ))}
            </div>
          </fieldset>
        </>
      )}

      {!ingresso && (
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
      )}

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
