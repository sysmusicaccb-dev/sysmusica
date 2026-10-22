"use client";

/**
 * Sysmusica — Formulário dos Dados do Ensaio (Local ou Regional).
 *
 * Regional: quem atende é sempre Ancião e há a "palavra" (obrigatória, até 500 caracteres).
 * Local: quem atende é Ancião, Diácono, Cooperador do Ofício ou Cooperador de RJM; não há palavra.
 * De 1 a 3 encarregados (nome + Cidade-UF do IBGE). Hino de abertura obrigatório (fora da lista de executados).
 * Zero hinos executados é permitido: dá para salvar e completar durante o ensaio.
 * Fora do prazo (2 h antes até 3 h depois do início) só o Administrador edita: a tela fica só para consulta.
 * Visual do protótipo: blocos coloridos (Ancião, Palavra, Encarregado, Hinos), hinos em duas listas e resumo ao lado.
 * O banco refaz todas as conferências ao salvar.
 */
import { useMemo, useState, type FormEvent, type ReactNode } from "react";
import { BookOpen, Music, RefreshCw, Save, User, Users, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
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
import { pluralEncarregado } from "../apresentacao";
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
  const mudar = (parte: Partial<EstadoEnsaio>) => setEstado((atual) => ({ ...atual, ...parte }));

  function digitarAbertura(texto: string) {
    setTextoAbertura(texto);
    const achado = acharPeloRotulo(opcoesAbertura, texto);
    const r = escolherAbertura(estado, achado?.id ?? "");
    setEstado(r.estado);
    setAvisoAbertura(r.saiuDaLista ? "Este hino estava na lista de executados e foi retirado de lá (a abertura não conta na lista)." : null);
  }

  // Se já há algo preenchido, pergunta antes; formulário vazio limpa direto
  function pedirLimpar() {
    const vazio = JSON.stringify(estado) === JSON.stringify(estadoVazio(modelo)) && textoAbertura === "";
    if (vazio) limpar();
    else setConfirmandoLimpar(true);
  }

  function limpar() {
    setConfirmandoLimpar(false);
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
  const rotulo = rotuloEncarregado(modelo);
  const regional = temPalavra(modelo);

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
          {/* Quem atende (Regional: Ancião; Local: o cargo escolhido) e, no Regional, a palavra exortada */}
          <div className={cn("grid gap-5", regional && "lg:grid-cols-2")}>
            <Bloco titulo={regional ? "Ancião" : "Quem atende"} icone={User} tom="azul">
              <div className="space-y-3">
                {!regional && (
                  <div className="space-y-1.5">
                    <label htmlFor="ensaio-cargo" className="text-sm font-semibold text-slate-800">
                      Cargo
                    </label>
                    <select
                      id="ensaio-cargo"
                      value={estado.atendeCargo}
                      onChange={(e) => mudar({ atendeCargo: e.target.value as EstadoEnsaio["atendeCargo"] })}
                      disabled={desabilitado}
                      className={classeInput + (erroDe("atende_cargo") ? bordaErro : bordaOk)}
                    >
                      <option value="">Selecione...</option>
                      {cargos.map((c) => (
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
                    {regional ? "Nome do Ancião que vai atender" : "Nome de quem vai atender"}
                  </label>
                  <input
                    id="ensaio-nome"
                    type="text"
                    maxLength={120}
                    value={estado.atendeNome}
                    onChange={(e) => mudar({ atendeNome: e.target.value })}
                    disabled={desabilitado}
                    placeholder={regional ? "Digite o nome do ancião..." : "Digite o nome..."}
                    className={classeInput + (erroDe("atende_nome") ? bordaErro : bordaOk)}
                  />
                  {erroDe("atende_nome") && <p className="text-xs text-red-700">{erroDe("atende_nome")}</p>}
                </div>
              </div>
            </Bloco>

            {regional && (
              <Bloco titulo="Palavra que foi exortada" icone={BookOpen} tom="azul">
                <div className="space-y-1.5">
                  <label htmlFor="ensaio-palavra" className="sr-only">
                    Palavra que foi exortada
                  </label>
                  <textarea
                    id="ensaio-palavra"
                    rows={4}
                    maxLength={PALAVRA_MAXIMA}
                    value={estado.palavra}
                    onChange={(e) => mudar({ palavra: e.target.value })}
                    disabled={desabilitado}
                    placeholder="Digite a palavra que foi exortada..."
                    className={cn(classeInput, "resize-none", erroDe("palavra") ? bordaErro : bordaOk)}
                  />
                  <p className="text-right text-xs text-slate-500" aria-live="polite">
                    {estado.palavra.length}/{PALAVRA_MAXIMA}
                  </p>
                  {erroDe("palavra") && <p className="text-xs text-red-700">{erroDe("palavra")}</p>}
                </div>
              </Bloco>
            )}
          </div>

          {/* Encarregados */}
          <Bloco titulo={rotulo} icone={Users} tom="verde">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-3">
                <p id="ensaio-qtd-rotulo" className="text-sm font-semibold text-slate-800">
                  Quantidade de {pluralEncarregado(rotulo)} que vão atender
                </p>
                <div role="group" aria-labelledby="ensaio-qtd-rotulo" className="flex items-center gap-2">
                  {Array.from({ length: MAXIMO_ENCARREGADOS }, (_, i) => i + 1).map((n) => (
                    <button
                      key={n}
                      type="button"
                      aria-pressed={estado.encarregados.length === n}
                      disabled={desabilitado}
                      onClick={() => mudar({ encarregados: ajustarQuantidade(estado.encarregados, n) })}
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
                {Array.from({ length: MAXIMO_ENCARREGADOS }, (_, i) => i).map((i) => {
                  const encarregado = estado.encarregados[i];
                  if (!encarregado) {
                    // Posição que não será usada: aparece apagada, como no protótipo
                    return (
                      <div key={i} className="space-y-1.5">
                        <label htmlFor={`enc-nome-${i}`} className="text-sm font-medium text-slate-500">
                          Nome do {i + 1}º {rotulo}
                        </label>
                        <input
                          id={`enc-nome-${i}`}
                          type="text"
                          disabled
                          placeholder={`Digite o nome do ${i + 1}º ${rotulo.toLowerCase()}...`}
                          className={classeInput + bordaOk}
                        />
                      </div>
                    );
                  }
                  return (
                    <div key={i} className="space-y-3">
                      <div className="space-y-1.5">
                        <label htmlFor={`enc-nome-${i}`} className="text-sm font-semibold text-slate-800">
                          Nome do {i + 1}º {rotulo}
                        </label>
                        <input
                          id={`enc-nome-${i}`}
                          type="text"
                          maxLength={120}
                          value={encarregado.nome}
                          onChange={(e) => alterarEncarregado(i, { nome: e.target.value })}
                          disabled={desabilitado}
                          placeholder={`Digite o nome do ${i + 1}º ${rotulo.toLowerCase()}...`}
                          className={classeInput + (erroDe(`encarregado_${i}_nome`) ? bordaErro : bordaOk)}
                        />
                        {erroDe(`encarregado_${i}_nome`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_nome`)}</p>}
                      </div>
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
                    </div>
                  );
                })}
              </div>
            </div>
          </Bloco>

          {/* Hinos */}
          <Bloco titulo="Hinos que foram executados" icone={Music} tom="violeta">
            <div className="space-y-5">
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
                {erroDe("hino_abertura") && <p className="text-xs text-red-700">{erroDe("hino_abertura")}</p>}
                {textoAbertura.trim() !== "" && estado.hinoAberturaId === "" && (
                  <p className="text-xs text-amber-800">Escolha um hino da lista de sugestões.</p>
                )}
                {avisoAbertura && <p className="text-xs text-slate-600">{avisoAbertura}</p>}
              </div>

              <div className="space-y-1.5">
                <SeletorHinos
                  hinos={hinos}
                  selecionados={estado.hinosIds}
                  abertura={estado.hinoAberturaId}
                  onChange={(ids) => mudar({ hinosIds: ids })}
                  disabled={desabilitado}
                />
                {erroDe("hinos") && <p className="text-xs text-red-700">{erroDe("hinos")}</p>}
              </div>
            </div>
          </Bloco>
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
        <ResumoDoEnsaio estado={estado} modelo={modelo} hinos={hinos} evento={evento} />
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
