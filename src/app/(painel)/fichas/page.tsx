"use client";

/**
 * Sysmusica — Administrativo > Fichas Musicais: catálogo das fichas da Comissão Musical e lista das fichas
 * já preenchidas na região de quem consulta. Hoje têm formulário: M02, M03 e M05 (preencher, guardar,
 * imprimir). O Secretário da Música marca o resultado; "Apto" altera o cadastro da pessoa.
 */
import { useCallback, useEffect, useState } from "react";
import Badge from "@/components/ui/Badge";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { abrirJanelaImpressao } from "@/lib/exportacao";
import { formatarDataHora } from "@/lib/datas";
import { opcoesMarca } from "@/lib/impressaoMarca";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import FormularioExtra from "@/modules/fichas/components/FormularioExtra";
import FormularioFicha from "@/modules/fichas/components/FormularioFicha";
import { quemPode } from "@/modules/fichas/quemPode";
import { ehTipoExtra, rotulosResultado } from "@/modules/fichas/layouts";
import { TIPOS_COM_FORMULARIO, lerDados, temFormulario } from "@/modules/fichas/dados";
import { montarHtmlFicha } from "@/modules/fichas/impressao";
import { FICHAS, rotuloDoResultado, tituloDaFicha } from "@/modules/fichas/regras";
import {
  definirResultadoFicha,
  excluirFicha,
  listarFichas,
  obterFicha,
  type FichaCompleta,
} from "@/modules/fichas/services/fichas";
import type { LinhaFicha, ResultadoFicha, TipoFicha } from "@/modules/fichas/tipos";

const BOTAO =
  "rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-50";

export default function FichasPage() {
  const { pode } = useSessao();
  const [itens, setItens] = useState<LinhaFicha[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [aviso, setAviso] = useState<{ texto: string; erro: boolean } | null>(null);
  const [editor, setEditor] = useState<{ tipo: TipoFicha; ficha: FichaCompleta | null } | null>(null);
  const [ocupado, setOcupado] = useState(false);

  const carregar = useCallback(async () => {
    try {
      setItens(await listarFichas());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar as fichas:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar as fichas.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  const falha = (e: unknown, padrao: string) => setAviso({ texto: e instanceof Error ? e.message : padrao, erro: true });

  async function abrirEdicao(linha: LinhaFicha) {
    setOcupado(true);
    try {
      setEditor({ tipo: linha.tipo, ficha: await obterFicha(linha.id) });
    } catch (e) {
      falha(e, "Não foi possível abrir a ficha.");
    } finally {
      setOcupado(false);
    }
  }

  // Abre a janela já no clique (antes de esperar o banco) para o navegador não bloquear como pop-up
  async function imprimir(linha: LinhaFicha) {
    const tipo = linha.tipo;
    if (!temFormulario(tipo)) return;
    const janela = abrirJanelaImpressao();
    if (!janela) {
      setAviso({ texto: "O navegador bloqueou a janela de impressão. Permita pop-ups para este site e tente de novo.", erro: true });
      return;
    }
    try {
      const ficha = await obterFicha(linha.id);
      const html = montarHtmlFicha({ tipo, dados: lerDados(ficha.dados), resultado: ficha.resultado, marca: opcoesMarca().marca });
      janela.document.open();
      janela.document.write(html);
      janela.document.close();
    } catch (e) {
      janela.close();
      falha(e, "Não foi possível imprimir a ficha.");
    }
  }

  async function marcar(linha: LinhaFicha, resultado: ResultadoFicha) {
    const quem = linha.membro_nome ?? "a pessoa";
    const pergunta =
      resultado === "APTO"
        ? `Marcar ${quem} como APTO? O cadastro da pessoa será alterado e a ficha não poderá mais ser editada.`
        : `Marcar ${quem} como NÃO APTO? A ficha não poderá mais ser editada.`;
    if (!window.confirm(pergunta)) return;
    setOcupado(true);
    try {
      setAviso({ texto: await definirResultadoFicha(linha.id, resultado), erro: false });
      await carregar();
    } catch (e) {
      falha(e, "Não foi possível registrar o resultado.");
    } finally {
      setOcupado(false);
    }
  }

  async function excluir(linha: LinhaFicha) {
    if (!window.confirm("Excluir esta ficha?")) return;
    setOcupado(true);
    try {
      await excluirFicha(linha.id);
      setAviso({ texto: "Ficha excluída.", erro: false });
      await carregar();
    } catch (e) {
      falha(e, "Não foi possível excluir a ficha.");
    } finally {
      setOcupado(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Fichas Musicais"
          descricao="Fichas e pedidos da Comissão Musical: preencher, guardar, imprimir e marcar o resultado."
        />

        {aviso && (
          <p role={aviso.erro ? "alert" : "status"} className={`mb-4 rounded-lg px-3 py-2 text-sm ${aviso.erro ? "bg-red-50 text-red-700" : "bg-emerald-50 text-emerald-800"}`}>
            {aviso.texto}
          </p>
        )}

        {/* Catálogo das fichas */}
        <section aria-label="Fichas disponíveis" className="mb-8 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {FICHAS.map((ficha) => {
            const pronta = TIPOS_COM_FORMULARIO.includes(ficha.tipo);
            return (
              <article key={ficha.tipo} className="flex flex-col rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
                <div className="mb-1 flex items-start justify-between gap-2">
                  <h2 className="text-sm font-bold text-slate-900">
                    {ficha.codigo === "Ficha" || ficha.codigo === "Formulário" ? "" : `${ficha.codigo} · `}
                    {ficha.titulo}
                  </h2>
                  <Badge variante={pronta ? "sucesso" : "neutro"}>{pronta ? "Disponível" : "Em breve"}</Badge>
                </div>
                <p className="text-xs text-slate-500">{ficha.descricao}</p>
                <p className="mt-1 flex-1 text-xs font-medium text-slate-600">Quem pode: {quemPode(ficha.tipo)}</p>
                {pronta && pode("fichas.criar") && (
                  <button type="button" onClick={() => setEditor({ tipo: ficha.tipo, ficha: null })} className="mt-3 self-start rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-brand-500">
                    Nova ficha
                  </button>
                )}
              </article>
            );
          })}
        </section>

        {/* Fichas já preenchidas */}
        <h2 className="mb-3 text-base font-bold text-slate-900">Fichas preenchidas</h2>
        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando as fichas...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar as fichas."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : itens.length === 0 ? (
          <EmptyState titulo="Nenhuma ficha preenchida ainda." descricao="As fichas preenchidas na sua região aparecem aqui." />
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th scope="col" className="px-4 py-3">Ficha</th>
                  <th scope="col" className="px-4 py-3">Pessoa</th>
                  <th scope="col" className="px-4 py-3">Casa de Oração</th>
                  <th scope="col" className="px-4 py-3">Criada em</th>
                  <th scope="col" className="px-4 py-3">Resultado</th>
                  <th scope="col" className="px-4 py-3">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {itens.map((ficha) => {
                  const comFormulario = TIPOS_COM_FORMULARIO.includes(ficha.tipo);
                  return (
                    <tr key={ficha.id}>
                      <td className="px-4 py-3 font-medium">{tituloDaFicha(ficha.tipo)}</td>
                      <td className="px-4 py-3">{ficha.membro_nome ?? "—"}</td>
                      <td className="px-4 py-3">{ficha.casa_nome ?? "—"}</td>
                      <td className="px-4 py-3 tabular-nums">{formatarDataHora(ficha.criado_em)}</td>
                      <td className="px-4 py-3">
                        <Badge variante={ficha.resultado === "APTO" ? "sucesso" : ficha.resultado === "NAO_APTO" ? "perigo" : "neutro"}>
                          {rotuloDoResultado(ficha.resultado, ficha.tipo)}
                        </Badge>
                      </td>
                      <td className="px-4 py-3">
                        {comFormulario && (
                          <div className="flex flex-wrap gap-1.5">
                            <button type="button" className={BOTAO} onClick={() => void imprimir(ficha)}>Imprimir</button>
                            {!ficha.resultado && pode("fichas.editar") && (
                              <button type="button" className={BOTAO} disabled={ocupado} onClick={() => void abrirEdicao(ficha)}>Editar</button>
                            )}
                            {!ficha.resultado && pode("fichas.resultado") && (
                              <>
                                <button type="button" className={BOTAO} disabled={ocupado} onClick={() => void marcar(ficha, "APTO")}>{rotulosResultado(ficha.tipo).sim}</button>
                                <button type="button" className={BOTAO} disabled={ocupado} onClick={() => void marcar(ficha, "NAO_APTO")}>{rotulosResultado(ficha.tipo).nao}</button>
                              </>
                            )}
                            {!ficha.aplicado_em && pode("fichas.excluir") && (
                              <button type="button" className={BOTAO} disabled={ocupado} onClick={() => void excluir(ficha)}>Excluir</button>
                            )}
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Drawer
        aberto={editor !== null}
        titulo={editor ? `${editor.ficha ? "Editar" : "Nova"} ficha ${editor.tipo}` : ""}
        descricao="Preencha os dados do pedido. Depois de salvar, use Imprimir na lista."
        onFechar={() => setEditor(null)}
      >
        {editor &&
          (ehTipoExtra(editor.tipo) ? (
            <FormularioExtra
              tipo={editor.tipo}
              ficha={editor.ficha}
              onCancelar={() => setEditor(null)}
              onSalvo={(mensagem) => {
                setEditor(null);
                setAviso({ texto: mensagem, erro: false });
                void carregar();
              }}
            />
          ) : (
            <FormularioFicha
              tipo={editor.tipo}
              ficha={editor.ficha}
              onCancelar={() => setEditor(null)}
              onSalvo={(mensagem) => {
                setEditor(null);
                setAviso({ texto: mensagem, erro: false });
                void carregar();
              }}
            />
          ))}
      </Drawer>
    </main>
  );
}
