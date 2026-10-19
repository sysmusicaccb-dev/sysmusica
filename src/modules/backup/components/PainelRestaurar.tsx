"use client";

/**
 * SysMúsica — Painel "Restaurar" (aparece abaixo da comparação, só para o Administrador).
 * Modos: Recuperar (padrão, seguro) e Espelhar (exige digitar ESPELHAR). A senha é pedida de novo.
 * O servidor faz um backup de segurança antes e aplica tudo em uma única transação.
 */
import { useState } from "react";
import { TEXTO_ESPELHAR, type ModoRestauracao } from "@/modules/backup/aplicacao";
import { restaurarBackup } from "@/modules/backup/services/restauracaoAplicarApi";
import type { GrupoDados } from "@/modules/backup/tabelas";

const classeBotaoPerigo =
  "inline-flex items-center gap-2 rounded-lg bg-red-600 px-3 py-2 text-sm font-medium text-white transition " +
  "hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60";

export default function PainelRestaurar({
  backupId,
  grupos,
  podeRestaurar,
}: {
  backupId: string;
  grupos: GrupoDados[];
  podeRestaurar: boolean;
}) {
  const [modo, setModo] = useState<ModoRestauracao>("recuperar");
  const [confirmacao, setConfirmacao] = useState("");
  const [senha, setSenha] = useState("");
  const [executando, setExecutando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState<string | null>(null);

  if (!podeRestaurar) return null;

  const pronto = senha !== "" && (modo === "recuperar" || confirmacao === TEXTO_ESPELHAR);

  async function aoRestaurar() {
    setExecutando(true);
    setErro(null);
    setSucesso(null);
    try {
      const resposta = await restaurarBackup({ id: backupId, grupos, modo, confirmacao, senha });
      setSucesso(resposta.mensagem);
      setSenha("");
      setConfirmacao("");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível restaurar.");
    } finally {
      setExecutando(false);
    }
  }

  return (
    <div className="space-y-4 rounded-xl border border-red-200 bg-red-50/40 p-4">
      <h3 className="text-sm font-semibold text-red-800">Restaurar este backup</h3>
      <p className="text-sm text-slate-700">
        Antes de qualquer mudança o sistema faz um <strong>backup de segurança</strong>, que serve para desfazer. A
        restauração acontece de uma vez só: se algo falhar, nada é alterado.
      </p>

      <fieldset className="space-y-2" disabled={executando}>
        <legend className="text-xs font-medium text-slate-600">Como restaurar</legend>
        <label className="flex items-start gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm">
          <input type="radio" name="modo" checked={modo === "recuperar"} onChange={() => setModo("recuperar")} className="mt-0.5" />
          <span>
            <span className="font-medium text-slate-800">Recuperar (recomendado)</span>
            <span className="block text-xs text-slate-500">
              Devolve o que foi apagado e desfaz as alterações. Não mexe no que foi criado depois do backup.
            </span>
          </span>
        </label>
        <label className="flex items-start gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm">
          <input type="radio" name="modo" checked={modo === "espelhar"} onChange={() => setModo("espelhar")} className="mt-0.5" />
          <span>
            <span className="font-medium text-slate-800">Espelhar</span>
            <span className="block text-xs text-slate-500">
              Deixa os dados idênticos ao backup: também remove o que foi criado depois dele (nunca remove usuários nem o
              histórico das portarias).
            </span>
          </span>
        </label>
      </fieldset>

      {modo === "espelhar" && (
        <div className="max-w-xs space-y-1.5">
          <label htmlFor="rest-confirmar" className="text-xs font-medium text-slate-600">
            Para confirmar, digite {TEXTO_ESPELHAR}
          </label>
          <input
            id="rest-confirmar"
            type="text"
            value={confirmacao}
            onChange={(e) => setConfirmacao(e.target.value)}
            disabled={executando}
            autoComplete="off"
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
          />
        </div>
      )}

      <div className="max-w-xs space-y-1.5">
        <label htmlFor="rest-senha" className="text-xs font-medium text-slate-600">
          Digite a sua senha de novo
        </label>
        <input
          id="rest-senha"
          type="password"
          value={senha}
          onChange={(e) => setSenha(e.target.value)}
          disabled={executando}
          autoComplete="current-password"
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
        />
      </div>

      <button type="button" className={classeBotaoPerigo} onClick={() => void aoRestaurar()} disabled={executando || !pronto}>
        {executando ? "Restaurando... (pode levar alguns segundos)" : "Restaurar agora"}
      </button>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
      {sucesso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          {sucesso} Clique em &quot;Comparar com os dados de hoje&quot; para conferir.
        </p>
      )}
    </div>
  );
}
