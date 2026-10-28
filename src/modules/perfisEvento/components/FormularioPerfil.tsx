"use client";

/**
 * Sysmusica — Formulário do perfil de evento (dentro do painel lateral).
 * Dados básicos (nome, descrição, modelo, status) e, embaixo, os CAMPOS da tela Dados do Ensaio que este perfil usa.
 * perfil = null -> novo; preenchido -> edição. O painel só monta este componente quando está aberto,
 * então os campos sempre abrem limpos (ou com os dados do perfil escolhido).
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { cn } from "@/lib/cn";
import { configPadrao, normalizarConfig, type ConfigEnsaio } from "@/modules/ensaio/perfilConfig";
import { DESCRICAO_MAXIMA, NOME_MAXIMO, formatarNomeTipo, type ModeloEnsaio } from "@/modules/tiposEvento/regras";
import { validarPerfil, type PerfilEvento } from "../regras";
import { salvarPerfil } from "../services/perfisEvento";
import EditorCamposPerfil from "./EditorCamposPerfil";

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
  // Campos da tela Dados do Ensaio (perfil novo começa com o padrão do modelo)
  const [config, setConfig] = useState<ConfigEnsaio>(() => normalizarConfig(perfil?.config, perfil?.modelo_base ?? "LOCAL"));
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  // O modelo vale para os tipos já ligados ao perfil: não muda enquanto estiver em uso
  const modeloTravado = editando && (perfil?.em_uso ?? 0) > 0;

  function trocarModelo(novo: ModeloEnsaio) {
    setModelo(novo);
    // Perfil novo: os campos acompanham o padrão do modelo escolhido
    if (!editando) setConfig(configPadrao(novo));
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    const erroForm = validarPerfil({ nome, descricao }, perfis, perfil?.id);
    if (erroForm) return setErro(erroForm);

    setSalvando(true);
    try {
      await salvarPerfil(perfil?.id ?? null, {
        nome: formatarNomeTipo(nome),
        descricao: descricao.trim(),
        modelo_base: modelo,
        ativo,
        config,
      });
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
          rows={2}
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
          Modelo do evento
        </label>
        <select
          id="modelo-perfil"
          value={modelo}
          onChange={(e) => trocarModelo(e.target.value as ModeloEnsaio)}
          disabled={salvando || modeloTravado}
          className={classeInput}
        >
          <option value="LOCAL">Local</option>
          <option value="REGIONAL">Regional</option>
        </select>
        <p className="text-xs text-slate-500">
          Define quem pode encerrar o evento: no modelo Local o Instrutor também encerra (menos nos Ensaios Técnicos); no
          Regional, só o Secretário da Música e os administradores. Os campos da tela são escolhidos abaixo.
          {modeloTravado && " Este perfil está em uso: troque o perfil dos tipos de evento para poder mudar o modelo."}
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

      <div className="space-y-2">
        <h3 className="text-base font-semibold text-slate-900">Campos da tela Dados do Ensaio</h3>
        <p className="text-xs text-slate-500">
          Ligue os campos que este perfil usa. A tela Dados do Ensaio mostra só o que estiver ligado aqui.
        </p>
        <EditorCamposPerfil config={config} onChange={setConfig} disabled={salvando} />
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <div className="sticky bottom-0 -mx-6 flex justify-end gap-2 border-t border-slate-200 bg-white px-6 py-3">
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
