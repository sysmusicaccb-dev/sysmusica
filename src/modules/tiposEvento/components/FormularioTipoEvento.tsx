"use client";

/**
 * Sysmusica — Formulário de tipo de evento (cartão da direita, sempre visível).
 * tipo = null -> "Novo Tipo de Evento"; preenchido -> "Editar Tipo de Evento".
 * A página troca o "key" do componente para recarregar os campos ao escolher outro tipo ou ao limpar.
 *
 * O campo "Dados do Ensaio" diz se os eventos deste tipo usam a tela Dados do Ensaio e em qual modelo
 * (Local ou Regional). O banco não deixa trocar o modelo de um tipo que já tem ensaios preenchidos.
 */
import { useState, type FormEvent } from "react";
import { Pencil, Plus, RefreshCw, Save } from "lucide-react";
import { cn } from "@/lib/cn";
import Link from "next/link";
import type { PerfilEvento } from "@/modules/perfisEvento/regras";
import { DESCRICAO_MAXIMA, NOME_MAXIMO, validarTipoEvento, type TipoEvento } from "../regras";
import { salvarTipoEvento } from "../services/tiposEvento";

interface FormularioTipoEventoProps {
  tipo: TipoEvento | null;
  tipos: TipoEvento[]; // todos, para impedir nomes repetidos
  perfis: PerfilEvento[]; // perfis do evento (campo Dados do Ensaio)
  podeGerenciarPerfis: boolean; // mostra o atalho para a aba Perfil do Evento
  onSalvo: (mensagem: string) => void | Promise<void>;
  onLimpar: () => void; // "Limpar": descarta a edição e volta ao formulário em branco
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 " +
  "placeholder:text-slate-400 focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioTipoEvento({ tipo, tipos, perfis, podeGerenciarPerfis, onSalvo, onLimpar }: FormularioTipoEventoProps) {
  const editando = tipo !== null;
  const [nome, setNome] = useState(tipo?.nome ?? "");
  const [descricao, setDescricao] = useState(tipo?.descricao ?? "");
  // Dados do Ensaio = perfil escolhido ("" = o tipo não usa a tela de ensaio). O modelo do tipo segue o perfil.
  const [perfilId, setPerfilId] = useState<string>(tipo?.perfil_id ?? "");
  const perfilEscolhido = perfis.find((p) => p.id === perfilId) ?? null;
  // Perfis ativos, mais o que o tipo já usa (mesmo que tenha sido desativado depois)
  const opcoesPerfil = perfis.filter((p) => p.ativo || p.id === tipo?.perfil_id);
  const [ativo, setAtivo] = useState(tipo?.ativo ?? true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroForm = validarTipoEvento({ nome, descricao }, tipos, tipo?.id);
    if (erroForm) return setErro(erroForm);

    setSalvando(true);
    try {
      await salvarTipoEvento(tipo?.id ?? null, {
        nome: nome.trim().replace(/\s+/g, " "),
        descricao: descricao.trim(),
        modelo_ensaio: perfilEscolhido?.modelo_base ?? null,
        perfil_id: perfilEscolhido?.id ?? null,
        ativo,
      });
      await onSalvo(editando ? `Tipo "${nome.trim()}" atualizado.` : `Tipo "${nome.trim()}" criado.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o tipo de evento.");
    } finally {
      setSalvando(false);
    }
  }

  const Icone = editando ? Pencil : Plus;

  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <header className="flex items-center gap-3 border-b border-slate-200 bg-brand-50 px-5 py-3.5">
        <span
          aria-hidden="true"
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-600 text-white"
        >
          <Icone className="h-4 w-4" />
        </span>
        <h2 className="text-base font-semibold text-slate-900">
          {editando ? "Editar Tipo de Evento" : "Novo Tipo de Evento"}
        </h2>
      </header>

      <form onSubmit={salvar} className="space-y-5 p-5">
        <div className="space-y-1.5">
          <label htmlFor="nome-tipo" className="text-sm font-semibold text-slate-800">
            Nome do Tipo de Evento <span className="text-red-600">*</span>
          </label>
          <input
            id="nome-tipo"
            type="text"
            required
            maxLength={NOME_MAXIMO}
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            disabled={salvando}
            placeholder="Digite o nome do tipo de evento..."
            className={classeInput}
          />
          {editando && (tipo?.em_uso ?? 0) > 0 && (
            <p className="text-xs text-slate-500">
              Ao renomear, os {tipo?.em_uso} evento(s) deste tipo passam a mostrar o novo nome.
            </p>
          )}
        </div>

        <div className="space-y-1.5">
          <label htmlFor="descricao-tipo" className="text-sm font-semibold text-slate-800">
            Descrição
          </label>
          <textarea
            id="descricao-tipo"
            rows={5}
            maxLength={DESCRICAO_MAXIMA}
            value={descricao}
            onChange={(e) => setDescricao(e.target.value)}
            disabled={salvando}
            placeholder="Digite uma descrição (opcional)..."
            className={cn(classeInput, "resize-none")}
          />
          <p className="text-right text-xs text-slate-500" aria-live="polite">
            {descricao.length}/{DESCRICAO_MAXIMA}
          </p>
        </div>

        <div className="space-y-1.5">
          <label htmlFor="modelo-tipo" className="text-sm font-semibold text-slate-800">
            Dados do Ensaio
          </label>
          <select
            id="modelo-tipo"
            value={perfilId}
            onChange={(e) => setPerfilId(e.target.value)}
            disabled={salvando}
            className={classeInput}
          >
            <option value="">Não usa (sem tela de ensaio)</option>
            {opcoesPerfil.map((p) => (
              <option key={p.id} value={p.id}>
                {p.nome}
                {p.ativo ? "" : " (inativo)"}
              </option>
            ))}
          </select>
          <p className="text-xs text-slate-500">
            O perfil define como a tela Dados do Ensaio funciona neste tipo de evento.
            {podeGerenciarPerfis && (
              <>
                {" "}
                <Link href="/perfil-evento" className="font-semibold text-brand-700 underline">
                  Gerenciar perfis
                </Link>
              </>
            )}
          </p>
        </div>

        <div className="space-y-2">
          <p id="status-tipo" className="text-sm font-semibold text-slate-800">
            Status
          </p>
          <div className="flex items-center gap-3">
            <button
              type="button"
              role="switch"
              aria-checked={ativo}
              aria-labelledby="status-tipo"
              disabled={salvando}
              onClick={() => setAtivo((atual) => !atual)}
              className={cn(
                "relative inline-flex h-8 w-14 shrink-0 items-center rounded-full transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-60",
                ativo ? "bg-emerald-500" : "bg-slate-300"
              )}
            >
              <span
                className={cn(
                  "inline-block h-6 w-6 transform rounded-full bg-white shadow transition",
                  ativo ? "translate-x-7" : "translate-x-1"
                )}
              />
            </button>
            <span className="text-base text-slate-700">{ativo ? "Ativo" : "Inativo"}</span>
          </div>
          <p className="text-xs text-slate-500">Tipos ativos aparecem na lista ao criar um evento.</p>
        </div>

        {erro && (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erro}
          </p>
        )}

        <div className="space-y-3">
          <button
            type="submit"
            disabled={salvando}
            className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition hover:bg-brand-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <Save className="h-5 w-5" aria-hidden="true" />
            {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Salvar"}
          </button>
          <button
            type="button"
            onClick={onLimpar}
            disabled={salvando}
            className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-slate-100 px-4 py-3 text-base font-semibold text-slate-800 transition hover:bg-slate-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <RefreshCw className="h-5 w-5" aria-hidden="true" />
            Limpar
          </button>
        </div>
      </form>
    </section>
  );
}
