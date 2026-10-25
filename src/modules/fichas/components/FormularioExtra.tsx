"use client";

/**
 * Sysmusica — Formulário das fichas M10 (avaliação de candidato), M11 (acompanhamento do GEM), pré-avaliação e
 * exames de organistas e necessidade/entrega de instrumentos. Aqui a pessoa PODE ainda não estar no cadastro:
 * se não for escolhida uma pessoa do cadastro, escolhe-se a Casa de Oração da ficha.
 * Os valores ficam em dados.notas (chave -> texto); as listas de campos vêm de layouts.ts (as mesmas da impressão).
 */
import { useEffect, useRef, useState, type ReactNode } from "react";
import { dadosIniciais, lerDados, preencherDoCadastro, type DadosFicha } from "../dados";
import { obterDadosDoMembro } from "../services/cadastro";
import {
  AREAS_GEM, COLUNAS_ORGANISTA, DESTINOS_ATENDIMENTO, ESCALA, FASES_NECESSIDADE, ITENS_NECESSIDADE, JUSTIFICATIVAS, M10_LEITURA, M10_PRATICA,
  ORG_HINARIO, ORG_METODO, ORG_PRATICA, ORG_TEORIA, PRESENCAS, TOTAL_AULAS_GEM, TOTAL_AVALIACOES_GEM, chaveAula, chaveAval, chaveOrg,
  mediaGem, resultadosOrganista, type Linha, type Opcao, type TipoExtra,
} from "../layouts";
import {
  buscarMembrosParaFicha, listarCasasParaFicha, salvarFicha, type FichaCompleta, type MembroBusca,
} from "../services/fichas";
import type { TipoFicha } from "../tipos";

interface Props {
  tipo: TipoFicha;
  ficha: FichaCompleta | null;
  onSalvo: (mensagem: string) => void;
  onCancelar: () => void;
}

const CAMPO =
  "mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";
const PEQUENO = "w-full rounded border border-slate-300 bg-white px-2 py-1 text-xs focus:outline-none focus:ring-2 focus:ring-brand-200";

/** Rótulo + entrada de texto (ou data / texto longo). */
function Entrada(p: { id: string; rotulo: string; valor: string; onChange: (v: string) => void; tipo?: "text" | "date"; longo?: boolean }) {
  return (
    <div>
      <label htmlFor={p.id} className="text-sm font-medium text-slate-700">{p.rotulo}</label>
      {p.longo ? (
        <textarea id={p.id} rows={3} value={p.valor} onChange={(ev) => p.onChange(ev.target.value)} className={CAMPO} />
      ) : (
        <input id={p.id} type={p.tipo ?? "text"} value={p.valor} onChange={(ev) => p.onChange(ev.target.value)} className={CAMPO} />
      )}
    </div>
  );
}

/** Grupo de opções (uma só marcada). Clicar na já marcada desmarca. */
function Opcoes(p: { nome: string; opcoes: Opcao[]; valor: string; onChange: (v: string) => void }) {
  return (
    <div className="flex flex-wrap gap-x-3 gap-y-1">
      {p.opcoes.map((o) => (
        <label key={o.valor} className="flex items-center gap-1 text-xs">
          <input type="radio" name={p.nome} checked={p.valor === o.valor} onChange={() => p.onChange(o.valor)} onClick={() => p.valor === o.valor && p.onChange("")} />
          {o.rotulo}
        </label>
      ))}
    </div>
  );
}

function Bloco({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <fieldset className="rounded-xl border border-slate-200 p-3">
      <legend className="px-1 text-sm font-semibold text-slate-800">{titulo}</legend>
      <div className="space-y-2">{children}</div>
    </fieldset>
  );
}

export default function FormularioExtra({ tipo, ficha, onSalvo, onCancelar }: Props) {
  const t = tipo as TipoExtra;
  const [membroId, setMembroId] = useState<string | null>(ficha?.membro_id ?? null);
  const [casaId, setCasaId] = useState<string>(ficha?.casa_oracao_id ?? "");
  const [casas, setCasas] = useState<{ id: string; nome: string }[]>([]);
  const [dados, setDados] = useState<DadosFicha>(() => (ficha ? lerDados(ficha.dados) : dadosIniciais()));
  const [termo, setTermo] = useState("");
  const [achados, setAchados] = useState<MembroBusca[]>([]);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Carrega as Casas de Oração da região (o setState só roda depois do await)
  useEffect(() => {
    let ativo = true;
    listarCasasParaFicha()
      .then((lista) => {
        if (ativo) setCasas(lista);
      })
      .catch(() => {
        if (ativo) setErro("Não foi possível carregar as Casas de Oração.");
      });
    return () => {
      ativo = false;
    };
  }, []);

  const campo = <K extends keyof DadosFicha>(k: K, v: DadosFicha[K]) => setDados((a) => ({ ...a, [k]: v }));
  const nota = (chave: string): string => dados.notas[chave] ?? "";
  const setNota = (chave: string, v: string) => setDados((a) => ({ ...a, notas: { ...a.notas, [chave]: v } }));

  function aoDigitarBusca(texto: string) {
    setTermo(texto);
    if (temporizador.current) clearTimeout(temporizador.current);
    if (texto.trim().length < 2) {
      setAchados([]);
      return;
    }
    temporizador.current = setTimeout(async () => {
      try {
        setAchados(await buscarMembrosParaFicha(texto));
      } catch (e) {
        setErro(e instanceof Error ? e.message : "Não foi possível buscar no cadastro.");
      }
    }, 350);
  }
  function escolher(m: MembroBusca) {
    setMembroId(m.id);
    if (m.casa_oracao_id) setCasaId(m.casa_oracao_id);
    setDados((a) => ({ ...a, nome: m.nome, comum: m.casa_nome ?? a.comum, instrumento: m.instrumento_nome ?? a.instrumento }));
    setAchados([]);
    setTermo("");
    // Puxa do cadastro tudo o que a ficha usa. Se falhar, a pessoa preenche na mão.
    void obterDadosDoMembro(m.id)
      .then((cadastro) => setDados((a) => preencherDoCadastro(tipo, a, cadastro)))
      .catch(() => undefined);
  }

  async function salvar() {
    if (dados.nome.trim() === "") return setErro("Informe o nome completo.");
    if (!membroId && casaId === "") return setErro("Escolha a Casa de Oração da ficha (ou uma pessoa do cadastro).");
    if (t === "NECESSIDADE_INSTRUMENTO" && nota("fase") === "") return setErro("Marque a fase do beneficiário.");
    setSalvando(true);
    setErro(null);
    try {
      await salvarFicha(ficha?.id ?? null, tipo, membroId, dados, membroId ? null : casaId);
      onSalvo(ficha ? "Ficha alterada." : "Ficha salva.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar a ficha.");
      setSalvando(false);
    }
  }

  // ---- Linha de avaliação (Ótimo/Bom/Regular/Fraco) para uma lista de itens
  const linhasNota = (linhas: Linha[], prefixo: string) =>
    linhas.map((l) => (
      <div key={l.chave} className="flex flex-wrap items-center gap-2">
        <span className="w-44 text-xs font-medium text-slate-700">{l.rotulo}</span>
        <Opcoes nome={`${prefixo}${l.chave}`} opcoes={ESCALA} valor={nota(`${prefixo}${l.chave}`)} onChange={(v) => setNota(`${prefixo}${l.chave}`, v)} />
      </div>
    ));

  const idBase = `fx-${tipo}`;
  return (
    <form
      className="space-y-4"
      onSubmit={(ev) => {
        ev.preventDefault();
        void salvar();
      }}
    >
      {/* Pessoa (opcional) e Casa de Oração */}
      <Bloco titulo="Pessoa e Casa de Oração">
        <div>
          <label htmlFor={`${idBase}-busca`} className="text-sm font-medium text-slate-700">Buscar no cadastro (opcional)</label>
          <input id={`${idBase}-busca`} type="search" value={termo} onChange={(ev) => aoDigitarBusca(ev.target.value)} placeholder="Digite parte do nome" className={CAMPO} autoComplete="off" />
          {achados.length > 0 && (
            <ul className="mt-1 max-h-40 overflow-y-auto rounded-lg border border-slate-200 bg-white text-sm shadow-sm">
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
          {membroId && <p className="mt-1 text-xs text-emerald-700">Ligada ao cadastro de {dados.nome}.</p>}
        </div>
        {!membroId && (
          <div>
            <label htmlFor={`${idBase}-casa`} className="text-sm font-medium text-slate-700">Casa de Oração da ficha</label>
            <select id={`${idBase}-casa`} value={casaId} onChange={(ev) => setCasaId(ev.target.value)} className={CAMPO}>
              <option value="">Selecione...</option>
              {casas.map((c) => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
            <p className="mt-1 text-xs text-slate-500">Sem pessoa do cadastro, a ficha fica na Casa escolhida.</p>
          </div>
        )}
      </Bloco>

      {t === "AVALIACAO_CANDIDATO" && (
        <>
          <Bloco titulo="Candidato">
            <Entrada id={`${idBase}-nome`} rotulo="Nome do candidato" valor={dados.nome} onChange={(v) => campo("nome", v)} />
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-inst`} rotulo="Instrumento" valor={dados.instrumento} onChange={(v) => campo("instrumento", v)} />
              <Entrada id={`${idBase}-data`} rotulo="Data do teste" tipo="date" valor={dados.data} onChange={(v) => campo("data", v)} />
              <Entrada id={`${idBase}-loc`} rotulo="Localidade" valor={dados.local} onChange={(v) => campo("local", v)} />
              <Entrada id={`${idBase}-mun`} rotulo="Município" valor={nota("municipio")} onChange={(v) => setNota("municipio", v)} />
              <Entrada id={`${idBase}-enc`} rotulo="Encarregado" valor={nota("encarregado")} onChange={(v) => setNota("encarregado", v)} />
            </div>
          </Bloco>
          <Bloco titulo="Leitura rítmica / métrica">
            {linhasNota(M10_LEITURA, "nota_")}
            <Entrada id={`${idBase}-ll`} rotulo="Lições / hinos avaliados" valor={nota("licoes_leitura")} onChange={(v) => setNota("licoes_leitura", v)} longo />
          </Bloco>
          <Bloco titulo="Prática instrumental">
            {linhasNota(M10_PRATICA, "nota_")}
            <Entrada id={`${idBase}-lp`} rotulo="Escalas / lições de método / hinos avaliados" valor={nota("licoes_pratica")} onChange={(v) => setNota("licoes_pratica", v)} longo />
          </Bloco>
          <Bloco titulo="Fechamento">
            <Entrada id={`${idBase}-hinos`} rotulo="Hinos avaliados" valor={nota("hinos")} onChange={(v) => setNota("hinos", v)} longo />
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-teoria`} rotulo="Nota da teoria" valor={nota("nota_teoria")} onChange={(v) => setNota("nota_teoria", v)} />
              <Entrada id={`${idBase}-reg`} rotulo="Regional que realizou o exame" valor={nota("regional")} onChange={(v) => setNota("regional", v)} />
            </div>
            <p className="text-xs text-slate-500">O resultado final (Apto) é marcado na lista, depois de salvar.</p>
          </Bloco>
        </>
      )}

      {t === "ACOMPANHAMENTO_GEM" && (
        <>
          <Bloco titulo="Aluno">
            <Entrada id={`${idBase}-nome`} rotulo="Aluno" valor={dados.nome} onChange={(v) => campo("nome", v)} />
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-inst`} rotulo="Instrumento" valor={dados.instrumento} onChange={(v) => campo("instrumento", v)} />
              <Entrada id={`${idBase}-fase`} rotulo="Fase" valor={nota("fase")} onChange={(v) => setNota("fase", v)} />
            </div>
            <div>
              <span className="text-sm font-medium text-slate-700">Área</span>
              <Opcoes nome={`${idBase}-area`} opcoes={AREAS_GEM} valor={nota("area")} onChange={(v) => setNota("area", v)} />
            </div>
          </Bloco>
          <Bloco titulo="Programação de aulas teóricas">
            <div className="space-y-1">
              {Array.from({ length: TOTAL_AULAS_GEM }, (_, i) => i + 1).map((i) => (
                <div key={i} className="grid grid-cols-[1.5rem_7rem_1fr_5.5rem_3.5rem] items-center gap-1">
                  <span className="text-xs text-slate-500">{String(i).padStart(2, "0")}</span>
                  <input aria-label={`Aula ${i}: data`} type="date" value={nota(chaveAula(i, "data"))} onChange={(ev) => setNota(chaveAula(i, "data"), ev.target.value)} className={PEQUENO} />
                  <input aria-label={`Aula ${i}: anotações`} value={nota(chaveAula(i, "obs"))} onChange={(ev) => setNota(chaveAula(i, "obs"), ev.target.value)} placeholder="Anotações" className={PEQUENO} />
                  <select aria-label={`Aula ${i}: presença`} value={nota(chaveAula(i, "pres"))} onChange={(ev) => setNota(chaveAula(i, "pres"), ev.target.value)} className={PEQUENO}>
                    <option value="">—</option>
                    {PRESENCAS.map((o) => <option key={o.valor} value={o.valor}>{o.rotulo}</option>)}
                  </select>
                  <select aria-label={`Aula ${i}: justificativa`} value={nota(chaveAula(i, "just"))} onChange={(ev) => setNota(chaveAula(i, "just"), ev.target.value)} className={PEQUENO}>
                    <option value="">—</option>
                    {JUSTIFICATIVAS.map((o) => <option key={o.valor} value={o.valor}>{o.valor}</option>)}
                  </select>
                </div>
              ))}
            </div>
          </Bloco>
          <Bloco titulo="Avaliações">
            {Array.from({ length: TOTAL_AVALIACOES_GEM }, (_, i) => i + 1).map((i) => (
              <div key={i} className="grid grid-cols-[1.5rem_7rem_4rem_1fr_5.5rem_3.5rem] items-center gap-1">
                <span className="text-xs text-slate-500">{String(i).padStart(2, "0")}</span>
                <input aria-label={`Avaliação ${i}: data`} type="date" value={nota(chaveAval(i, "data"))} onChange={(ev) => setNota(chaveAval(i, "data"), ev.target.value)} className={PEQUENO} />
                <input aria-label={`Avaliação ${i}: nota`} value={nota(chaveAval(i, "nota"))} onChange={(ev) => setNota(chaveAval(i, "nota"), ev.target.value)} placeholder="Nota" className={PEQUENO} />
                <input aria-label={`Avaliação ${i}: anotações`} value={nota(chaveAval(i, "obs"))} onChange={(ev) => setNota(chaveAval(i, "obs"), ev.target.value)} placeholder="Anotações" className={PEQUENO} />
                <select aria-label={`Avaliação ${i}: presença`} value={nota(chaveAval(i, "pres"))} onChange={(ev) => setNota(chaveAval(i, "pres"), ev.target.value)} className={PEQUENO}>
                  <option value="">—</option>
                  {PRESENCAS.map((o) => <option key={o.valor} value={o.valor}>{o.rotulo}</option>)}
                </select>
                <select aria-label={`Avaliação ${i}: justificativa`} value={nota(chaveAval(i, "just"))} onChange={(ev) => setNota(chaveAval(i, "just"), ev.target.value)} className={PEQUENO}>
                  <option value="">—</option>
                  {JUSTIFICATIVAS.map((o) => <option key={o.valor} value={o.valor}>{o.valor}</option>)}
                </select>
              </div>
            ))}
            <p className="text-sm">Média: <b>{mediaGem(dados.notas) || "—"}</b> <span className="text-xs text-slate-500">(calculada pelas notas)</span></p>
            <Entrada id={`${idBase}-data`} rotulo="Data da ficha" tipo="date" valor={dados.data} onChange={(v) => campo("data", v)} />
          </Bloco>
        </>
      )}

      {(t === "PRE_AVALIACAO_ORGANISTA" || t === "EXAME_ORGANISTA") && (
        <>
          <Bloco titulo="Candidata e professora">
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-nome`} rotulo="Nome da candidata" valor={dados.nome} onChange={(v) => campo("nome", v)} />
              <Entrada id={`${idBase}-comum`} rotulo="Congregação" valor={dados.comum} onChange={(v) => campo("comum", v)} />
              <Entrada id={`${idBase}-prof`} rotulo="Nome da professora" valor={nota("professora")} onChange={(v) => setNota("professora", v)} />
              <Entrada id={`${idBase}-profc`} rotulo="Congregação da professora" valor={nota("professora_comum")} onChange={(v) => setNota("professora_comum", v)} />
            </div>
          </Bloco>
          {COLUNAS_ORGANISTA.map((col) => {
            const k = (campoNome: string) => chaveOrg(col.chave, campoNome);
            return (
              <Bloco key={col.chave} titulo={col.titulo}>
                <p className="text-xs font-semibold text-slate-600">Teoria e solfejo</p>
                {ORG_TEORIA.map((l) => (
                  <Entrada key={l.chave} id={`${idBase}-${k(l.chave)}`} rotulo={l.rotulo} valor={nota(k(l.chave))} onChange={(v) => setNota(k(l.chave), v)} />
                ))}
                <div className="flex flex-wrap items-center gap-2">
                  <span className="w-44 text-xs font-medium text-slate-700">Avaliação teórica</span>
                  <Opcoes nome={`${idBase}-${k("aval_teorica")}`} opcoes={ESCALA} valor={nota(k("aval_teorica"))} onChange={(v) => setNota(k("aval_teorica"), v)} />
                </div>
                <p className="text-xs font-semibold text-slate-600">{col.metodo}</p>
                {ORG_METODO.map((l) => (
                  <Entrada key={l.chave} id={`${idBase}-${k(l.chave)}`} rotulo={l.rotulo} valor={nota(k(l.chave))} onChange={(v) => setNota(k(l.chave), v)} />
                ))}
                <p className="text-xs font-semibold text-slate-600">Hinário</p>
                {ORG_HINARIO.map((l) => (
                  <Entrada key={l.chave} id={`${idBase}-${k(l.chave)}`} rotulo={l.rotulo} valor={nota(k(l.chave))} onChange={(v) => setNota(k(l.chave), v)} />
                ))}
                <p className="text-xs font-semibold text-slate-600">Avaliação prática</p>
                {ORG_PRATICA.map((l) => (
                  <div key={l.chave} className="flex flex-wrap items-center gap-2">
                    <span className="w-44 text-xs font-medium text-slate-700">{l.rotulo}</span>
                    <Opcoes nome={`${idBase}-${k(`p_${l.chave}`)}`} opcoes={ESCALA} valor={nota(k(`p_${l.chave}`))} onChange={(v) => setNota(k(`p_${l.chave}`), v)} />
                  </div>
                ))}
                <div>
                  <span className="text-sm font-medium text-slate-700">Resultado</span>
                  <Opcoes nome={`${idBase}-${k("resultado")}`} opcoes={resultadosOrganista(col)} valor={nota(k("resultado"))} onChange={(v) => setNota(k("resultado"), v)} />
                </div>
                <div className="grid gap-2 sm:grid-cols-2">
                  <Entrada id={`${idBase}-${k("examinadora")}`} rotulo="Examinadora" valor={nota(k("examinadora"))} onChange={(v) => setNota(k("examinadora"), v)} />
                  <Entrada id={`${idBase}-${k("data")}`} rotulo={t === "EXAME_ORGANISTA" ? "Data do teste/exame" : "Data do teste"} tipo="date" valor={nota(k("data"))} onChange={(v) => setNota(k("data"), v)} />
                </div>
              </Bloco>
            );
          })}
        </>
      )}

      {t === "NECESSIDADE_INSTRUMENTO" && (
        <>
          <Bloco titulo="Regional e data">
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-reg`} rotulo="Regional administrativa de" valor={nota("regional")} onChange={(v) => setNota("regional", v)} />
              <Entrada id={`${idBase}-data`} rotulo="Data" tipo="date" valor={dados.data} onChange={(v) => campo("data", v)} />
            </div>
          </Bloco>
          <Bloco titulo="Dados do beneficiário e da necessidade">
            <Entrada id={`${idBase}-nome`} rotulo="Nome" valor={dados.nome} onChange={(v) => campo("nome", v)} />
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-idade`} rotulo="Idade" valor={nota("idade")} onChange={(v) => setNota("idade", v)} />
              <Entrada id={`${idBase}-pais`} rotulo="Nome dos pais (se menor de idade)" valor={nota("pais")} onChange={(v) => setNota("pais", v)} />
              <Entrada id={`${idBase}-comum`} rotulo="Congregação local" valor={dados.comum} onChange={(v) => campo("comum", v)} />
              <Entrada id={`${idBase}-setor`} rotulo="Setor" valor={nota("setor")} onChange={(v) => setNota("setor", v)} />
              <Entrada id={`${idBase}-cidade`} rotulo="Cidade" valor={dados.local} onChange={(v) => campo("local", v)} />
            </div>
            <div>
              <span className="text-sm font-medium text-slate-700">Fase</span>
              <Opcoes nome={`${idBase}-fase`} opcoes={FASES_NECESSIDADE} valor={nota("fase")} onChange={(v) => setNota("fase", v)} />
            </div>
            <Entrada id={`${idBase}-motivo`} rotulo="Motivo da necessidade" valor={nota("motivo")} onChange={(v) => setNota("motivo", v)} longo />
            <div className="flex flex-wrap gap-x-4 gap-y-1">
              {ITENS_NECESSIDADE.map((i) => (
                <label key={i.chave} className="flex items-center gap-1 text-sm">
                  <input type="checkbox" checked={nota(i.chave) === "1"} onChange={(ev) => setNota(i.chave, ev.target.checked ? "1" : "")} />
                  {i.rotulo}
                </label>
              ))}
            </div>
            <Entrada id={`${idBase}-esp`} rotulo="Especificar o instrumento ou acessório necessário" valor={nota("especificar")} onChange={(v) => setNota("especificar", v)} longo />
          </Bloco>
          <Bloco titulo="Orçamentos e responsáveis">
            <div className="grid gap-2 sm:grid-cols-3">
              <Entrada id={`${idBase}-o1`} rotulo="1º orçamento" valor={nota("orc1")} onChange={(v) => setNota("orc1", v)} />
              <Entrada id={`${idBase}-o2`} rotulo="2º orçamento" valor={nota("orc2")} onChange={(v) => setNota("orc2", v)} />
              <Entrada id={`${idBase}-o3`} rotulo="3º orçamento" valor={nota("orc3")} onChange={(v) => setNota("orc3", v)} />
              <Entrada id={`${idBase}-ne`} rotulo="Encarregado local de orquestra" valor={nota("nome_encarregado")} onChange={(v) => setNota("nome_encarregado", v)} />
              <Entrada id={`${idBase}-nm`} rotulo="Ministério local" valor={nota("nome_ministerio")} onChange={(v) => setNota("nome_ministerio", v)} />
              <Entrada id={`${idBase}-nd`} rotulo="Diácono local" valor={nota("nome_diacono")} onChange={(v) => setNota("nome_diacono", v)} />
            </div>
          </Bloco>
          <Bloco titulo="Reunião de deliberação">
            <div className="grid gap-2 sm:grid-cols-2">
              <Entrada id={`${idBase}-dd`} rotulo="Data da deliberação" tipo="date" valor={nota("delib_data")} onChange={(v) => setNota("delib_data", v)} />
              <Entrada id={`${idBase}-dv`} rotulo="Valor aprovado (R$)" valor={nota("delib_valor")} onChange={(v) => setNota("delib_valor", v)} />
            </div>
            <Opcoes nome={`${idBase}-dest`} opcoes={DESTINOS_ATENDIMENTO} valor={nota("delib_destino")} onChange={(v) => setNota("delib_destino", v)} />
            <p className="text-xs text-slate-500">Aprovado / Não aprovado é marcado na lista, depois de salvar.</p>
          </Bloco>
        </>
      )}

      {erro && <p role="alert" className="text-sm text-red-600">{erro}</p>}
      <div className="flex justify-end gap-2 pt-2">
        <button type="button" onClick={onCancelar} className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">Cancelar</button>
        <button type="submit" disabled={salvando} className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-500 disabled:opacity-60">
          {salvando ? "Salvando..." : "Salvar ficha"}
        </button>
      </div>
    </form>
  );
}
