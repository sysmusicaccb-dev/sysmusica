"use client";

/**
 * Sysmusica — Formulário dos Dados do Ensaio, desenhado pelo PERFIL do tipo de evento.
 *
 * Os campos que aparecem vêm da configuração do perfil (Eventos > Perfil do Evento):
 *   - Quem atendeu (cargos permitidos e rótulos) e, no mesmo cartão, a pergunta "Houve hino de abertura?";
 *   - Palavra exortada (obrigatória ou não, com limite);
 *   - Encarregados (cargos Regional/Local/Instrutor, mínimo e máximo, Cidade-UF);
 *   - Hinos executados (duas listas).
 * Fora do prazo (2 h antes até 3 h depois do início) só o Administrador edita: a tela fica só para consulta.
 * O banco refaz todas as conferências ao salvar.
 */
import { useMemo, useState, type FormEvent, type ReactNode } from "react";
import { BookOpen, ClipboardList, Music, RefreshCw, Save, User, Users, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import type { Cidade } from "../cidades";
import {
  CARGOS_ENCARREGADO,
  normalizarConfig,
  rotuloEncarregados,
  rotuloNomeEncarregado,
  tituloBlocoEncarregados,
  verboAtendeu,
} from "../perfilConfig";
import { CARGOS_ATENDE, acharPeloRotulo, motivoSemEdicao, type ErroCampo } from "../regras";
import {
  ajustarQuantidadeCfg,
  cargosEmUso,
  escolherAberturaCfg,
  estadoDosDadosCfg,
  estadoVazioCfg,
  montarCargaCfg,
  usaAbertura,
  validarEnsaioCfg,
  type EstadoEnsaioCfg,
} from "../regrasPerfil";
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
  "w-full rounded-lg border bg-white px-3 py-2.5 text-sm text-slate-900 placeholder:text-slate-400 " +
  "focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-60 ";
const bordaOk = "border-slate-300 focus:border-brand-500 focus:ring-brand-200";
const bordaErro = "border-red-400 focus:border-red-500 focus:ring-red-200";

export default function FormularioEnsaio({ resposta, hinos, cidades, temPermissaoPreencher, lateral, onSalvo }: FormularioEnsaioProps) {
  const { evento, dados, pode_editar: podeEditar } = resposta;
  // Configuração do perfil do tipo de evento (o banco já manda normalizada; aqui só garante o formato)
  const config = useMemo(() => normalizarConfig(resposta.config, evento.modelo_ensaio), [resposta.config, evento.modelo_ensaio]);

  const [estado, setEstado] = useState<EstadoEnsaioCfg>(() => estadoDosDadosCfg(dados, config));
  // Texto digitado no campo do hino de abertura (a escolha vale quando bate exatamente com uma opção)
  const [textoAbertura, setTextoAbertura] = useState(() => {
    const atual = hinos.find((h) => h.id === dados?.hino_abertura_id);
    return atual ? rotuloCompleto(atual) : "";
  });
  const [erros, setErros] = useState<ErroCampo[]>([]);
  const [erroGeral, setErroGeral] = useState<string | null>(null);
  const [avisoAbertura, setAvisoAbertura] = useState<string | null>(null);
  const [salvando, setSalvando] = useState(false);
  // Janela "Limpar o formulário?": evita apagar sem querer os dados de um ensaio em andamento
  const [confirmandoLimpar, setConfirmandoLimpar] = useState(false);

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
  const mudar = (parte: Partial<EstadoEnsaioCfg>) => setEstado((atual) => ({ ...atual, ...parte }));

  function digitarAbertura(texto: string) {
    setTextoAbertura(texto);
    const achado = acharPeloRotulo(opcoesAbertura, texto);
    const r = escolherAberturaCfg(estado, achado?.id ?? "");
    setEstado(r.estado);
    setAvisoAbertura(r.saiuDaLista ? "Este hino estava na lista de executados e foi retirado de lá (a abertura não conta na lista)." : null);
  }

  // Responder "Houve hino de abertura?": Não apaga a escolha do hino
  function responderAbertura(valor: "SIM" | "NAO") {
    if (valor === "NAO") {
      setTextoAbertura("");
      setAvisoAbertura(null);
      mudar({ houveAbertura: "NAO", hinoAberturaId: "" });
    } else {
      mudar({ houveAbertura: "SIM" });
    }
  }

  // Se já há algo preenchido, pergunta antes; formulário vazio limpa direto
  function pedirLimpar() {
    const vazio = JSON.stringify(estado) === JSON.stringify(estadoVazioCfg(config)) && textoAbertura === "";
    if (vazio) limpar();
    else setConfirmandoLimpar(true);
  }

  function limpar() {
    setConfirmandoLimpar(false);
    setEstado(estadoVazioCfg(config));
    setTextoAbertura("");
    setErros([]);
    setErroGeral(null);
    setAvisoAbertura(null);
  }

  function alterarEncarregado(indice: number, parte: Partial<EstadoEnsaioCfg["encarregados"][number]>) {
    mudar({ encarregados: estado.encarregados.map((e, i) => (i === indice ? { ...e, ...parte } : e)) });
  }

  function mudarExtra(id: string, valor: string) {
    setEstado((atual) => ({ ...atual, extras: { ...atual.extras, [id]: valor } }));
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (desabilitado) return; // evita envio duplicado e envio sem permissão
    setErroGeral(null);

    const encontrados = validarEnsaioCfg(estado, config);
    setErros(encontrados);
    if (encontrados.length > 0) {
      setErroGeral("Corrija os campos destacados antes de salvar.");
      return;
    }

    setSalvando(true);
    try {
      await salvarDadosEnsaio(evento.id, montarCargaCfg(estado, config));
      await onSalvo(dados ? "Dados do ensaio atualizados." : "Dados do ensaio registrados.");
    } catch (e) {
      setErroGeral(e instanceof Error ? e.message : "Não foi possível salvar os dados do ensaio.");
    } finally {
      setSalvando(false);
    }
  }

  const qa = config.quem_atendeu;
  const enc = config.encarregados;
  const camposExtras = config.campos_extras.filter((c) => c.ativo);
  const cargosAtende = CARGOS_ATENDE.filter((c) => qa.cargos.includes(c.codigo));
  const abertura = config.hino_abertura.modo;
  // Título e "Quantidade de ..." acompanham o cargo escolhido nas linhas
  const cargosAtuais = cargosEmUso(estado.encarregados, config);
  const tituloEnc = tituloBlocoEncarregados(cargosAtuais);
  const rotuloQtd = rotuloEncarregados(cargosAtuais);
  const faixaQtd = Array.from({ length: enc.maximo - enc.minimo + 1 }, (_, i) => enc.minimo + i);

  // Campo do hino de abertura (com a pergunta Sim/Não quando o perfil pede). Fica no cartão de quem atendeu.
  const campoAbertura =
    abertura === "nao_usa" ? null : (
      <div className="space-y-3">
        {abertura === "pergunta" && (
          <div className="space-y-1.5">
            <p id="ensaio-houve-abertura" className="text-sm font-semibold text-slate-800">
              Houve hino de abertura?
            </p>
            <div role="radiogroup" aria-labelledby="ensaio-houve-abertura" className="flex items-center gap-2">
              {(["SIM", "NAO"] as const).map((opcao) => (
                <button
                  key={opcao}
                  type="button"
                  role="radio"
                  aria-checked={estado.houveAbertura === opcao}
                  disabled={desabilitado}
                  onClick={() => responderAbertura(opcao)}
                  className={cn(
                    "h-10 w-20 rounded-lg border text-sm font-semibold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50",
                    estado.houveAbertura === opcao
                      ? "border-brand-600 bg-brand-600 text-white"
                      : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"
                  )}
                >
                  {opcao === "SIM" ? "Sim" : "Não"}
                </button>
              ))}
            </div>
          </div>
        )}
        {usaAbertura(config, estado) && (
          <div className="space-y-1.5">
            <label htmlFor="ensaio-abertura" className="text-sm font-semibold text-slate-800">
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
            {textoAbertura.trim() !== "" && estado.hinoAberturaId === "" && (
              <p className="text-xs text-amber-800">Escolha um hino da lista de sugestões.</p>
            )}
            {avisoAbertura && <p className="text-xs text-slate-600">{avisoAbertura}</p>}
          </div>
        )}
        {erroDe("hino_abertura") && <p className="text-xs text-red-700">{erroDe("hino_abertura")}</p>}
      </div>
    );

  return (
    <>
    <form onSubmit={salvar} className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]" noValidate>
      <div className="space-y-5">
        {bloqueio && (
          <p role="status" className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            {bloqueio}
          </p>
        )}

        <fieldset disabled={!podeEditar} className="space-y-5 disabled:opacity-90">
          {/* Quem atendeu (com o hino de abertura embaixo) e a palavra exortada */}
          {(qa.ativo || config.palavra.ativo || campoAbertura) && (
            <div className={cn("grid gap-5", qa.ativo && config.palavra.ativo && "lg:grid-cols-2")}>
              {qa.ativo ? (
                <Bloco titulo={qa.titulo} icone={User} tom="azul">
                  <div className="space-y-3">
                    {cargosAtende.length > 1 && (
                      <div className="space-y-1.5">
                        <label htmlFor="ensaio-cargo" className="text-sm font-semibold text-slate-800">
                          Ministério
                        </label>
                        <select
                          id="ensaio-cargo"
                          value={estado.atendeCargo}
                          onChange={(e) => mudar({ atendeCargo: e.target.value as EstadoEnsaioCfg["atendeCargo"] })}
                          disabled={desabilitado}
                          className={classeInput + (erroDe("atende_cargo") ? bordaErro : bordaOk)}
                        >
                          <option value="">Selecione...</option>
                          {cargosAtende.map((c) => (
                            <option key={c.codigo} value={c.codigo}>
                              {c.rotulo}
                            </option>
                          ))}
                        </select>
                        {erroDe("atende_cargo") && <p className="text-xs text-red-700">{erroDe("atende_cargo")}</p>}
                      </div>
                    )}
                    <div className="space-y-1.5">
                      <label htmlFor="ensaio-nome" className="text-sm font-semibold text-slate-800">
                        {qa.rotulo_nome}
                      </label>
                      <input
                        id="ensaio-nome"
                        type="text"
                        maxLength={120}
                        value={estado.atendeNome}
                        onChange={(e) => mudar({ atendeNome: e.target.value })}
                        disabled={desabilitado}
                        placeholder="Digite o nome..."
                        className={classeInput + (erroDe("atende_nome") ? bordaErro : bordaOk)}
                      />
                      {erroDe("atende_nome") && <p className="text-xs text-red-700">{erroDe("atende_nome")}</p>}
                    </div>
                    {campoAbertura}
                  </div>
                </Bloco>
              ) : (
                campoAbertura && (
                  <Bloco titulo="Hino de abertura" icone={Music} tom="violeta">
                    {campoAbertura}
                  </Bloco>
                )
              )}

              {config.palavra.ativo && (
                <Bloco titulo="Palavra que foi exortada" icone={BookOpen} tom="azul">
                  <div className="space-y-1.5">
                    <label htmlFor="ensaio-palavra" className="sr-only">
                      Palavra que foi exortada
                    </label>
                    <textarea
                      id="ensaio-palavra"
                      rows={4}
                      maxLength={config.palavra.limite}
                      value={estado.palavra}
                      onChange={(e) => mudar({ palavra: e.target.value })}
                      disabled={desabilitado}
                      placeholder="Digite a palavra que foi exortada..."
                      className={cn(classeInput, "resize-none", erroDe("palavra") ? bordaErro : bordaOk)}
                    />
                    <p className="text-right text-xs text-slate-500" aria-live="polite">
                      {estado.palavra.length}/{config.palavra.limite}
                    </p>
                    {erroDe("palavra") && <p className="text-xs text-red-700">{erroDe("palavra")}</p>}
                  </div>
                </Bloco>
              )}
            </div>
          )}

          {/* Encarregados */}
          {enc.ativo && (
            <Bloco titulo={tituloEnc} icone={Users} tom="verde">
              <div className="space-y-4">
                <div className="flex flex-wrap items-center gap-3">
                  <p id="ensaio-qtd-rotulo" className="text-sm font-semibold text-slate-800">
                    Quantidade de {rotuloQtd} que {verboAtendeu(estado.encarregados.length)}
                  </p>
                  <div role="group" aria-labelledby="ensaio-qtd-rotulo" className="flex items-center gap-2">
                    {faixaQtd.map((n) => (
                      <button
                        key={n}
                        type="button"
                        aria-pressed={estado.encarregados.length === n}
                        disabled={desabilitado}
                        onClick={() => mudar({ encarregados: ajustarQuantidadeCfg(estado.encarregados, n, config) })}
                        className={cn(
                          "h-10 w-16 rounded-lg border text-sm font-semibold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50",
                          estado.encarregados.length === n
                            ? "border-brand-600 bg-brand-600 text-white"
                            : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"
                        )}
                      >
                        {n}
                      </button>
                    ))}
                  </div>
                </div>
                {erroDe("encarregados") && <p className="text-xs text-red-700">{erroDe("encarregados")}</p>}

                <div className="grid gap-4 sm:grid-cols-3">
                  {Array.from({ length: enc.maximo }, (_, i) => i).map((i) => {
                    const encarregado = estado.encarregados[i];
                    if (!encarregado) {
                      // Posição que não será usada: aparece apagada, como no protótipo
                      return (
                        <div key={i} className="space-y-1.5">
                          <label htmlFor={`enc-nome-${i}`} className="text-sm font-medium text-slate-500">
                            {rotuloNomeEncarregado(i, 2, enc.cargos, "")}
                          </label>
                          <input
                            id={`enc-nome-${i}`}
                            type="text"
                            disabled
                            placeholder={`Digite o ${rotuloNomeEncarregado(i, 2, enc.cargos, "").toLowerCase()}...`}
                            className={classeInput + bordaOk}
                          />
                        </div>
                      );
                    }
                    return (
                      <div key={i} className="space-y-3">
                        {enc.cargos.length > 1 && (
                          <div className="space-y-1.5">
                            <label htmlFor={`enc-cargo-${i}`} className="text-sm font-semibold text-slate-800">
                              {rotuloNomeEncarregado(i, estado.encarregados.length, enc.cargos, encarregado.cargo)}
                            </label>
                            <select
                              id={`enc-cargo-${i}`}
                              value={encarregado.cargo}
                              onChange={(e) => alterarEncarregado(i, { cargo: e.target.value as typeof encarregado.cargo })}
                              disabled={desabilitado}
                              className={classeInput + (erroDe(`encarregado_${i}_cargo`) ? bordaErro : bordaOk)}
                            >
                              <option value="">Selecione...</option>
                              {CARGOS_ENCARREGADO.filter((c) => enc.cargos.includes(c.codigo)).map((c) => (
                                <option key={c.codigo} value={c.codigo}>
                                  {c.rotulo}
                                </option>
                              ))}
                            </select>
                            {erroDe(`encarregado_${i}_cargo`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_cargo`)}</p>}
                          </div>
                        )}
                        <div className="space-y-1.5">
                          <label htmlFor={`enc-nome-${i}`} className="text-sm font-semibold text-slate-800">
                            {rotuloNomeEncarregado(i, estado.encarregados.length, enc.cargos, encarregado.cargo)}
                          </label>
                          <input
                            id={`enc-nome-${i}`}
                            type="text"
                            maxLength={120}
                            value={encarregado.nome}
                            onChange={(e) => alterarEncarregado(i, { nome: e.target.value })}
                            disabled={desabilitado}
                            placeholder={`Digite o ${rotuloNomeEncarregado(i, estado.encarregados.length, enc.cargos, encarregado.cargo).toLowerCase()}...`}
                            className={classeInput + (erroDe(`encarregado_${i}_nome`) ? bordaErro : bordaOk)}
                          />
                          {erroDe(`encarregado_${i}_nome`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_nome`)}</p>}
                        </div>
                        {enc.cidade_uf && (
                          <div className="space-y-1.5">
                            <label htmlFor={`enc-cidade-${i}`} className="text-sm font-semibold text-slate-800">
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
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            </Bloco>
          )}

          {/* Hinos executados */}
          {config.hinos_executados.ativo && (
            <Bloco titulo="Hinos que foram executados" icone={Music} tom="violeta">
              <div className="space-y-1.5">
                <SeletorHinos
                  hinos={hinos}
                  selecionados={estado.hinosIds}
                  abertura={usaAbertura(config, estado) ? estado.hinoAberturaId : ""}
                  onChange={(ids) => mudar({ hinosIds: ids })}
                  disabled={desabilitado}
                />
                {erroDe("hinos") && <p className="text-xs text-red-700">{erroDe("hinos")}</p>}
              </div>
            </Bloco>
          )}

          {/* Informações adicionais: campos extras criados no perfil do evento */}
          {camposExtras.length > 0 && (
            <Bloco titulo="Informações adicionais" icone={ClipboardList} tom="azul">
              <div className="grid gap-4 sm:grid-cols-2">
                {camposExtras.map((c) => {
                  const idCampo = `ensaio-extra-${c.id}`;
                  const valor = estado.extras[c.id] ?? "";
                  const erro = erroDe(`extra_${c.id}`);
                  const classe = classeInput + (erro ? bordaErro : bordaOk);
                  return (
                    <div key={c.id} className={cn("space-y-1.5", c.tipo === "texto_longo" && "sm:col-span-2")}>
                      <label htmlFor={idCampo} id={`${idCampo}-rotulo`} className="text-sm font-semibold text-slate-800">
                        {c.nome}
                        {c.obrigatorio && <span className="font-normal text-slate-500"> (obrigatório)</span>}
                      </label>
                      {c.tipo === "texto_curto" && (
                        <input id={idCampo} type="text" maxLength={200} value={valor} disabled={desabilitado} className={classe} onChange={(e) => mudarExtra(c.id, e.target.value)} />
                      )}
                      {c.tipo === "texto_longo" && (
                        <textarea id={idCampo} rows={3} maxLength={1000} value={valor} disabled={desabilitado} className={cn(classe, "resize-none")} onChange={(e) => mudarExtra(c.id, e.target.value)} />
                      )}
                      {c.tipo === "numero" && (
                        <input id={idCampo} type="text" inputMode="decimal" value={valor} disabled={desabilitado} className={classe} onChange={(e) => mudarExtra(c.id, e.target.value)} />
                      )}
                      {c.tipo === "lista" && (
                        <select id={idCampo} value={valor} disabled={desabilitado} className={classe} onChange={(e) => mudarExtra(c.id, e.target.value)}>
                          <option value="">Selecione...</option>
                          {c.opcoes.map((o) => (
                            <option key={o} value={o}>
                              {o}
                            </option>
                          ))}
                        </select>
                      )}
                      {c.tipo === "sim_nao" && (
                        <div role="radiogroup" aria-labelledby={`${idCampo}-rotulo`} className="flex items-center gap-2">
                          {(["SIM", "NAO"] as const).map((opcao) => (
                            <button
                              key={opcao}
                              type="button"
                              role="radio"
                              aria-checked={valor === opcao}
                              disabled={desabilitado}
                              // Clicar de novo na resposta marcada limpa (útil quando o campo não é obrigatório)
                              onClick={() => mudarExtra(c.id, valor === opcao ? "" : opcao)}
                              className={cn(
                                "h-10 w-20 rounded-lg border text-sm font-semibold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50",
                                valor === opcao ? "border-brand-600 bg-brand-600 text-white" : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"
                              )}
                            >
                              {opcao === "SIM" ? "Sim" : "Não"}
                            </button>
                          ))}
                        </div>
                      )}
                      {erro && <p className="text-xs text-red-700">{erro}</p>}
                    </div>
                  );
                })}
              </div>
            </Bloco>
          )}
        </fieldset>

        {erroGeral && (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroGeral}
          </p>
        )}

        {podeEditar && (
          <div className="grid gap-3 sm:grid-cols-[1fr_2fr]">
            <button
              type="button"
              onClick={pedirLimpar}
              disabled={salvando}
              className="inline-flex items-center justify-center gap-2 rounded-lg bg-slate-100 px-4 py-3 text-base font-semibold text-slate-800 transition hover:bg-slate-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50"
            >
              <RefreshCw className="h-5 w-5" aria-hidden="true" />
              Limpar
            </button>
            <button
              type="submit"
              disabled={salvando}
              className="inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition hover:bg-emerald-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <Save className="h-5 w-5" aria-hidden="true" />
              {salvando ? "Salvando..." : dados ? "Salvar alterações" : "Salvar Dados do Ensaio"}
            </button>
          </div>
        )}
      </div>

      <aside className="space-y-4 lg:sticky lg:top-20 lg:self-start">
        <ResumoDoEnsaio estado={estado} config={config} hinos={hinos} evento={evento} />
        {lateral}
      </aside>
    </form>
    <ConfirmDialog
      aberto={confirmandoLimpar}
      titulo="Limpar o formulário?"
      mensagem={
        <p>
          Tudo o que foi preenchido e <strong>ainda não foi salvo</strong> será perdido. Esta ação não pode ser desfeita.
        </p>
      }
      textoConfirmar="Limpar"
      onConfirmar={limpar}
      onCancelar={() => setConfirmandoLimpar(false)}
    />
    </>
  );
}

/** Bloco colorido do formulário (cabeçalho com ícone e título), como no protótipo. */
function Bloco({
  titulo,
  icone: Icone,
  tom,
  children,
}: {
  titulo: string;
  icone: LucideIcon;
  tom: "azul" | "verde" | "violeta";
  children: ReactNode;
}) {
  const cabecalho = { azul: "bg-brand-50", verde: "bg-emerald-50", violeta: "bg-violet-50" }[tom];
  const iconeCor = { azul: "text-brand-600", verde: "text-emerald-600", violeta: "text-violet-600" }[tom];
  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <header className={cn("flex items-center gap-2 border-b border-slate-200 px-4 py-3", cabecalho)}>
        <Icone className={cn("h-5 w-5", iconeCor)} aria-hidden="true" />
        <h2 className="text-base font-semibold text-slate-900">{titulo}</h2>
      </header>
      <div className="p-4">{children}</div>
    </section>
  );
}
