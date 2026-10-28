"use client";

/**
 * Sysmusica — Formulário do perfil de evento (dentro do painel lateral).
 * perfil = null -> novo; preenchido -> edição. O painel só monta este componente quando está aberto,
 * então os campos sempre abrem limpos (ou com os dados do perfil escolhido).
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { cn } from "@/lib/cn";
import { DESCRICAO_MAXIMA, NOME_MAXIMO, ROTULO_MODELO, formatarNomeTipo, type ModeloEnsaio } from "@/modules/tiposEvento/regras";
import { validarPerfil, type PerfilEvento } from "../regras";
import { salvarPerfil } from "../services/perfisEvento";

interface FormularioPerfilProps {
  perfil: PerfilEvento | null;
  perfis: PerfilEvento[]; // todos, para impedir nomes repetidos
  onSalvo: (mensagem: string) => void | Promise<void>;
  onCancelar: () => void;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 " +
  "placeholder:text-slate-400 focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioPerfil({ perfil, perfis, onSalvo, onCancelar }: FormularioPerfilProps) {
  const editando = perfil !== null;
  const [nome, setNome] = useState(perfil?.nome ?? "");
  const [descricao, setDescricao] = useState(perfil?.descricao ?? "");
  const [modelo, setModelo] = useState<ModeloEnsaio>(perfil?.modelo_base ?? "LOCAL");
  const [ativo, setAtivo] = useState(perfil?.ativo ?? true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    const erroForm = validarPerfil({ nome, descricao }, perfis, perfil?.id);
    if (erroForm) return setErro(erroForm);

    setSalvando(true);
    try {
      await salvarPerfil(perfil?.id ?? null, { nome: formatarNomeTipo(nome), descricao: descricao.trim(), modelo_base: modelo, ativo });
      await onSalvo(editando ? `Perfil "${formatarNomeTipo(nome)}" atualizado.` : `Perfil "${formatarNomeTipo(nome)}" criado.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o perfil.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="nome-perfil" className="text-sm font-semibold text-slate-800">
          Nome do Perfil <span className="text-red-600">*</span>
        </label>
        <input
          id="nome-perfil"
          type="text"
          required
          maxLength={NOME_MAXIMO}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex.: Ensaio Técnico"
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="descricao-perfil" className="text-sm font-semibold text-slate-800">
          Descrição
        </label>
        <textarea
          id="descricao-perfil"
          rows={3}
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
        <label htmlFor="modelo-perfil" className="text-sm font-semibold text-slate-800">
          Comportamento base
        </label>
        <select
          id="modelo-perfil"
          value={modelo}
          onChange={(e) => setModelo(e.target.value as ModeloEnsaio)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="LOCAL">{ROTULO_MODELO.LOCAL}</option>
          <option value="REGIONAL">{ROTULO_MODELO.REGIONAL}</option>
        </select>
        <p className="text-xs text-slate-500">
          Regional: quem atende é sempre Ancião e há a palavra. Local: quem atende pode ser Ancião, Diácono ou
          Cooperador, sem palavra. A configuração campo a campo do perfil chega na próxima etapa.
        </p>
      </div>

      <div className="space-y-2">
        <p id="status-perfil" className="text-sm font-semibold text-slate-800">
          Status
        </p>
        <div className="flex items-center gap-3">
          <button
            type="button"
            role="switch"
            aria-checked={ativo}
            aria-labelledby="status-perfil"
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
        <p className="text-xs text-slate-500">Só perfis ativos aparecem para escolher no Tipo do Evento.</p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <div className="flex justify-end gap-2">
        <Button variante="secundario" onClick={onCancelar} disabled={salvando}>
          Cancelar
        </Button>
        <Button type="submit" disabled={salvando}>
          {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Salvar"}
        </Button>
      </div>
    </form>
  );
}
