"use client";

/**
 * SysMúsica — Formulário dos Dados do Ensaio (Local ou Regional).
 *
 * Regional: quem atende é sempre Ancião e há a "palavra" (obrigatória, até 500 caracteres).
 * Local: quem atende é Ancião, Diácono, Cooperador do Ofício ou Cooperador de RJM; não há palavra.
 * De 1 a 3 encarregados (nome + Cidade-UF do IBGE). Hino de abertura obrigatório (fora da lista de executados).
 * Zero hinos executados é permitido: dá para salvar e completar durante o ensaio.
 * Fora do prazo (2 h antes até 3 h depois do início) só o Administrador edita: a tela fica só para consulta.
 * O banco refaz todas as conferências ao salvar.
 */
import { useMemo, useState, type FormEvent, type ReactNode } from "react";
import Button from "@/components/ui/Button";
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import type { Cidade } from "../cidades";
import {
  CARGOS_ATENDE,
  MAXIMO_ENCARREGADOS,
  PALAVRA_MAXIMA,
  acharPeloRotulo,
  ajustarQuantidade,
  cargosDoModelo,
  escolherAbertura,
  estadoDosDados,
  estadoVazio,
  montarCarga,
  motivoSemEdicao,
  rotuloEncarregado,
  temPalavra,
  validarEnsaio,
  type EstadoEnsaio,
  type ErroCampo,
} from "../regras";
import { salvarDadosEnsaio } from "../services/ensaio";
import type { RespostaEnsaio } from "../tipos";
import CampoCidadeUf from "./CampoCidadeUf";
import ResumoDoEnsaio from "./ResumoDoEnsaio";
import SeletorHinos from "./SeletorHinos";

interface FormularioEnsaioProps {
  resposta: RespostaEnsaio;
  hinos: Hino[];
  cidades: Cidade[];
  temPermissaoPreencher: boolean; // ensaio.registrar
  /** Conteúdo extra na coluna lateral (ex.: totais do painel ao vivo). */
  lateral?: ReactNode;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm " +
  "focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-60 ";
const bordaOk = "border-slate-300 focus:border-brand-500 focus:ring-brand-200";
const bordaErro = "border-red-400 focus:border-red-500 focus:ring-red-200";

export default function FormularioEnsaio({ resposta, hinos, cidades, temPermissaoPreencher, lateral, onSalvo }: FormularioEnsaioProps) {
  const { evento, dados, pode_editar: podeEditar } = resposta;
  const modelo = evento.modelo_ensaio;

  const [estado, setEstado] = useState<EstadoEnsaio>(() => estadoDosDados(dados, modelo));
  // Texto digitado no campo do hino de abertura (a escolha vale quando bate exatamente com uma opção)
  const [textoAbertura, setTextoAbertura] = useState(() => {
    const atual = hinos.find((h) => h.id === dados?.hino_abertura_id);
    return atual ? rotuloCompleto(atual) : "";
  });
  const [erros, setErros] = useState<ErroCampo[]>([]);
  const [erroGeral, setErroGeral] = useState<string | null>(null);
  const [avisoAbertura, setAvisoAbertura] = useState<string | null>(null);
  const [salvando, setSalvando] = useState(false);

  const bloqueio = motivoSemEdicao(evento, podeEditar, temPermissaoPreencher);
  const desabilitado = !podeEditar || salvando;

  // Opções do hino de abertura: ativos (e o já gravado, mesmo que desativado depois)
  const opcoesAbertura = useMemo(
    () =>
      hinos
        .filter((h) => h.ativo || h.id === dados?.hino_abertura_id)
        .map((hino) => ({ rotulo: rotuloCompleto(hino), hino })),
    [hinos, dados?.hino_abertura_id]
  );

  const erroDe = (campo: string) => erros.find((e) => e.campo === campo)?.mensagem;
  const mudar = (parte: Partial<EstadoEnsaio>) => setEstado((atual) => ({ ...atual, ...parte }));

  function digitarAbertura(texto: string) {
    setTextoAbertura(texto);
    const achado = acharPeloRotulo(opcoesAbertura, texto);
    const r = escolherAbertura(estado, achado?.id ?? "");
    setEstado(r.estado);
    setAvisoAbertura(r.saiuDaLista ? "Este hino estava na lista de executados e foi retirado de lá (a abertura não conta na lista)." : null);
  }

  function limpar() {
    setEstado(estadoVazio(modelo));
    setTextoAbertura("");
    setErros([]);
    setErroGeral(null);
    setAvisoAbertura(null);
  }

  function alterarEncarregado(indice: number, parte: Partial<EstadoEnsaio["encarregados"][number]>) {
    mudar({ encarregados: estado.encarregados.map((e, i) => (i === indice ? { ...e, ...parte } : e)) });
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (desabilitado) return; // evita envio duplicado e envio sem permissão
    setErroGeral(null);

    const encontrados = validarEnsaio(estado, modelo);
    setErros(encontrados);
    if (encontrados.length > 0) {
      setErroGeral("Corrija os campos destacados antes de salvar.");
      return;
    }

    setSalvando(true);
    try {
      await salvarDadosEnsaio(evento.id, montarCarga(estado, modelo));
      await onSalvo(dados ? "Dados do ensaio atualizados." : "Dados do ensaio registrados.");
    } catch (e) {
      setErroGeral(e instanceof Error ? e.message : "Não foi possível salvar os dados do ensaio.");
    } finally {
      setSalvando(false);
    }
  }

  const cargos = CARGOS_ATENDE.filter((c) => cargosDoModelo(modelo).includes(c.codigo));

  return (
    <form onSubmit={salvar} className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]" noValidate>
      <div className="space-y-6">
        {bloqueio && (
          <p role="status" className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            {bloqueio}
          </p>
        )}

        <fieldset disabled={!podeEditar} className="space-y-6 disabled:opacity-90">
          {/* Quem atende */}
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <h2 className="text-base font-semibold text-slate-900">Quem atende</h2>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <label htmlFor="ensaio-cargo" className="text-sm font-medium text-slate-700">
                  Cargo
                </label>
                <select
                  id="ensaio-cargo"
                  value={estado.atendeCargo}
                  onChange={(e) => mudar({ atendeCargo: e.target.value as EstadoEnsaio["atendeCargo"] })}
                  disabled={desabilitado}
                  className={classeInput + (erroDe("atende_cargo") ? bordaErro : bordaOk)}
                >
                  {modelo === "LOCAL" && <option value="">Selecione...</option>}
                  {cargos.map((c) => (
                    <option key={c.codigo} value={c.codigo}>
                      {c.rotulo}
                    </option>
                  ))}
                </select>
                {erroDe("atende_cargo") && <p className="text-xs text-red-700">{erroDe("atende_cargo")}</p>}
              </div>
              <div className="space-y-1.5">
                <label htmlFor="ensaio-nome" className="text-sm font-medium text-slate-700">
                  Nome
                </label>
                <input
                  id="ensaio-nome"
                  type="text"
                  maxLength={120}
                  value={estado.atendeNome}
                  onChange={(e) => mudar({ atendeNome: e.target.value })}
                  disabled={desabilitado}
                  className={classeInput + (erroDe("atende_nome") ? bordaErro : bordaOk)}
                />
                {erroDe("atende_nome") && <p className="text-xs text-red-700">{erroDe("atende_nome")}</p>}
              </div>
            </div>

            {temPalavra(modelo) && (
              <div className="space-y-1.5">
                <label htmlFor="ensaio-palavra" className="text-sm font-medium text-slate-700">
                  Palavra
                </label>
                <textarea
                  id="ensaio-palavra"
                  rows={3}
                  maxLength={PALAVRA_MAXIMA}
                  value={estado.palavra}
                  onChange={(e) => mudar({ palavra: e.target.value })}
                  disabled={desabilitado}
                  className={classeInput + (erroDe("palavra") ? bordaErro : bordaOk)}
                />
                <p className="text-right text-xs text-slate-500">
                  {estado.palavra.length}/{PALAVRA_MAXIMA}
                </p>
                {erroDe("palavra") && <p className="text-xs text-red-700">{erroDe("palavra")}</p>}
              </div>
            )}
          </section>

          {/* Encarregados */}
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-base font-semibold text-slate-900">{rotuloEncarregado(modelo)}</h2>
              <div role="group" aria-label="Quantidade de encarregados" className="flex items-center gap-1">
                <span className="mr-1 text-xs text-slate-500">Quantos?</span>
                {Array.from({ length: MAXIMO_ENCARREGADOS }, (_, i) => i + 1).map((n) => (
                  <button
                    key={n}
                    type="button"
                    aria-pressed={estado.encarregados.length === n}
                    disabled={desabilitado}
                    onClick={() => mudar({ encarregados: ajustarQuantidade(estado.encarregados, n) })}
                    className={
                      "h-8 w-8 rounded-lg text-sm font-semibold transition disabled:opacity-50 " +
                      (estado.encarregados.length === n ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
                    }
                  >
                    {n}
                  </button>
                ))}
              </div>
            </div>
            {erroDe("encarregados") && <p className="text-xs text-red-700">{erroDe("encarregados")}</p>}

            {estado.encarregados.map((encarregado, i) => (
              <div key={i} className="grid gap-3 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <label htmlFor={`enc-nome-${i}`} className="text-sm font-medium text-slate-700">
                    Nome {estado.encarregados.length > 1 ? `(${i + 1})` : ""}
                  </label>
                  <input
                    id={`enc-nome-${i}`}
                    type="text"
                    maxLength={120}
                    value={encarregado.nome}
                    onChange={(e) => alterarEncarregado(i, { nome: e.target.value })}
                    disabled={desabilitado}
                    className={classeInput + (erroDe(`encarregado_${i}_nome`) ? bordaErro : bordaOk)}
                  />
                  {erroDe(`encarregado_${i}_nome`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_nome`)}</p>}
                </div>
                <div className="space-y-1.5">
                  <label htmlFor={`enc-cidade-${i}`} className="text-sm font-medium text-slate-700">
                    Cidade-UF
                  </label>
                  <CampoCidadeUf
                    id={`enc-cidade-${i}`}
                    valor={encarregado.cidadeUf}
                    onChange={(valor) => alterarEncarregado(i, { cidadeUf: valor })}
                    cidades={cidades}
                    disabled={desabilitado}
                    invalido={!!erroDe(`encarregado_${i}_cidade`)}
                  />
                  {erroDe(`encarregado_${i}_cidade`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_cidade`)}</p>}
                </div>
              </div>
            ))}
          </section>

          {/* Hinos */}
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <h2 className="text-base font-semibold text-slate-900">Hinos</h2>
            <div className="space-y-1.5">
              <label htmlFor="ensaio-abertura" className="text-sm font-medium text-slate-700">
                Hino de abertura
              </label>
              <input
                id="ensaio-abertura"
                type="text"
                list="ensaio-abertura-opcoes"
                autoComplete="off"
                value={textoAbertura}
                onChange={(e) => digitarAbertura(e.target.value)}
                disabled={desabilitado}
                placeholder="Digite o número ou o título e escolha na lista"
                className={classeInput + (erroDe("hino_abertura") ? bordaErro : bordaOk)}
              />
              <datalist id="ensaio-abertura-opcoes">
                {opcoesAbertura.map((o) => (
                  <option key={o.hino.id} value={o.rotulo} />
                ))}
              </datalist>
              {erroDe("hino_abertura") && <p className="text-xs text-red-700">{erroDe("hino_abertura")}</p>}
              {textoAbertura.trim() !== "" && estado.hinoAberturaId === "" && (
                <p className="text-xs text-amber-800">Escolha um hino da lista de sugestões.</p>
              )}
              {avisoAbertura && <p className="text-xs text-slate-600">{avisoAbertura}</p>}
            </div>

            <div className="space-y-1.5">
              <p className="text-sm font-medium text-slate-700">Hinos executados</p>
              <SeletorHinos
                hinos={hinos}
                selecionados={estado.hinosIds}
                abertura={estado.hinoAberturaId}
                onChange={(ids) => mudar({ hinosIds: ids })}
                disabled={desabilitado}
              />
              {erroDe("hinos") && <p className="text-xs text-red-700">{erroDe("hinos")}</p>}
            </div>
          </section>
        </fieldset>

        {erroGeral && (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroGeral}
          </p>
        )}

        {podeEditar && (
          <div className="flex flex-wrap gap-3">
            <Button type="submit" disabled={salvando}>
              {salvando ? "Salvando..." : dados ? "Salvar alterações" : "Salvar dados do ensaio"}
            </Button>
            <button
              type="button"
              onClick={limpar}
              disabled={salvando}
              className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50 disabled:opacity-50"
            >
              Limpar formulário
            </button>
          </div>
        )}
      </div>

      <aside className="space-y-4 lg:sticky lg:top-4 lg:self-start">
        <ResumoDoEnsaio estado={estado} modelo={modelo} hinos={hinos} />
        {lateral}
      </aside>
    </form>
  );
}
