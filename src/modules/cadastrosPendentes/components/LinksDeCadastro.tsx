"use client";

/**
 * Sysmusica — Painel "Link de cadastro da região" (Cadastros Pendentes).
 * Cada administração gera o próprio link do formulário público. Quem abrir o link vê só as Casas de Oração daquela
 * região; se digitar uma casa que não está cadastrada, o pedido chega para quem aprova naquela região.
 * Gerar de novo para a mesma região devolve o link que já existe. Desativar faz o link deixar de abrir o formulário.
 */
import { useCallback, useEffect, useState } from "react";
import { Check, Link2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import Button from "@/components/ui/Button";
import { urlDoLinkDeCadastro, type NivelLink } from "../linksRegras";
import {
  criarLink,
  desativarLink,
  listarLinks,
  listarRegioesParaLink,
  type LinkCadastro,
  type RegiaoParaLink,
} from "../services/links";

const CLASSE_SELECT =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]";

export default function LinksDeCadastro({ onMensagem }: { onMensagem?: (texto: string) => void }) {
  const [links, setLinks] = useState<LinkCadastro[]>([]);
  const [regioes, setRegioes] = useState<RegiaoParaLink[]>([]);
  const [escolha, setEscolha] = useState(""); // "NIVEL:id"
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState(false);
  const [copiadoId, setCopiadoId] = useState<string | null>(null);
  const [desativando, setDesativando] = useState<string | null>(null); // id aguardando confirmação

  const carregar = useCallback(async () => {
    try {
      const [l, r] = await Promise.all([listarLinks(), listarRegioesParaLink()]);
      setLinks(l);
      setRegioes(r);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os links.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  async function gerar() {
    const [nivel, alvo] = escolha.split(":");
    if (!nivel || !alvo) return setErro("Escolha a região do link.");
    setOcupado(true);
    setErro(null);
    try {
      await criarLink(nivel as NivelLink, alvo);
      setEscolha("");
      await carregar();
      onMensagem?.("Link gerado. Use o botão Copiar para enviar às pessoas.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível gerar o link.");
    } finally {
      setOcupado(false);
    }
  }

  async function copiar(link: LinkCadastro) {
    const url = urlDoLinkDeCadastro(window.location.origin, link.codigo);
    try {
      await navigator.clipboard.writeText(url);
      setCopiadoId(link.id);
      setTimeout(() => setCopiadoId(null), 2500);
    } catch {
      // Sem permissão para a área de transferência: mostra o link para copiar à mão
      window.prompt("Copie o link do cadastro:", url);
    }
  }

  async function desativar(id: string) {
    setOcupado(true);
    setErro(null);
    try {
      await desativarLink(id);
      setDesativando(null);
      await carregar();
      onMensagem?.("Link desativado: ele não abre mais o formulário.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível desativar o link.");
    } finally {
      setOcupado(false);
    }
  }

  if (carregando) return <p className="text-sm text-slate-500">Carregando...</p>;

  return (
    <div className="space-y-6">
      <p className="text-sm text-slate-600">
        Envie o link da sua região às pessoas que vão se cadastrar. Quem abrir vê só as Casas de Oração dela, e os pedidos
        chegam para quem aprova nessa região.
      </p>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <section className="space-y-2">
        <label htmlFor="regiao-link" className="block text-sm font-medium text-slate-800">
          Gerar link para
        </label>
        <select id="regiao-link" value={escolha} onChange={(e) => setEscolha(e.target.value)} className={CLASSE_SELECT}>
          <option value="">Escolha a região...</option>
          {regioes.map((r) => (
            <option key={`${r.nivel}:${r.alvo_id}`} value={`${r.nivel}:${r.alvo_id}`}>
              {r.nivel} · {r.nome}
              {r.caminho ? ` (${r.caminho})` : ""}
            </option>
          ))}
        </select>
        <Button onClick={() => void gerar()} disabled={ocupado || escolha === ""} className="w-full">
          Gerar link
        </Button>
      </section>

      <section className="space-y-3">
        <h3 className="text-sm font-semibold text-slate-800">Links da minha abrangência</h3>
        {links.length === 0 ? (
          <p className="text-sm text-slate-500">Nenhum link gerado ainda.</p>
        ) : (
          <ul className="space-y-3">
            {links.map((l) => (
              <li key={l.id} className="rounded-lg border border-slate-200 px-4 py-3">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-sm font-medium text-slate-900">{l.rotulo}</span>
                  <Badge variante="marca">{l.nivel}</Badge>
                  <Badge variante={l.ativo ? "sucesso" : "neutro"}>{l.ativo ? "Ativo" : "Desativado"}</Badge>
                </div>
                <p className="mt-1 text-xs text-slate-500">
                  {l.pendentes} {l.pendentes === 1 ? "pedido aguardando" : "pedidos aguardando"}
                  {l.criado_por_nome ? ` · criado por ${l.criado_por_nome}` : ""}
                </p>
                {l.ativo && (
                  <div className="mt-3 flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      onClick={() => void copiar(l)}
                      className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50"
                    >
                      {copiadoId === l.id ? (
                        <Check className="h-4 w-4 text-emerald-600" aria-hidden="true" />
                      ) : (
                        <Link2 className="h-4 w-4" aria-hidden="true" />
                      )}
                      {copiadoId === l.id ? "Link copiado!" : "Copiar link"}
                    </button>
                    {desativando === l.id ? (
                      <>
                        <span className="text-xs text-slate-600">Desativar este link?</span>
                        <button
                          type="button"
                          disabled={ocupado}
                          onClick={() => void desativar(l.id)}
                          className="rounded-lg bg-red-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50"
                        >
                          Sim, desativar
                        </button>
                        <button
                          type="button"
                          onClick={() => setDesativando(null)}
                          className="rounded-lg px-3 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-100"
                        >
                          Cancelar
                        </button>
                      </>
                    ) : (
                      <button
                        type="button"
                        onClick={() => setDesativando(l.id)}
                        className="rounded-lg px-3 py-1.5 text-sm font-medium text-red-700 hover:bg-red-50"
                      >
                        Desativar
                      </button>
                    )}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
