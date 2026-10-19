"use client";

/**
 * SysMúsica — Página /administracao/backup/restauracao (só o Administrador): escolhe um backup e os grupos
 * de dados e mostra o que mudou desde então (apagado, alterado, novo). Nesta etapa NADA é restaurado:
 * a tela só lê e compara. CPF e segredos aparecem como "(protegido)".
 */
import { useEffect, useState } from "react";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import { dataHoraSalvador, ROTULO_TIPO } from "@/modules/backup/regras";
import type { ItemDiferenca, ResultadoComparacao, ResultadoTabela } from "@/modules/backup/restauracao";
import { listarBackups } from "@/modules/backup/services/backupApi";
import { compararBackup } from "@/modules/backup/services/restauracaoApi";
import { GRUPOS_DADOS, type GrupoDados } from "@/modules/backup/tabelas";
import type { RegistroBackup } from "@/modules/backup/tipos";

const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-3 py-2 text-sm font-medium text-white transition " +
  "hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";

function rotuloBackup(b: RegistroBackup): string {
  const tipo = (ROTULO_TIPO as Record<string, string>)[b.tipo] ?? b.tipo;
  return `${dataHoraSalvador(new Date(b.criado_em))} — ${tipo}`;
}

function Etiqueta({ n, texto, classe }: { n: number; texto: string; classe: string }) {
  if (n === 0) return null;
  return <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${classe}`}>{n} {texto}</span>;
}

function Lista({ titulo, itens, total, classe }: { titulo: string; itens: ItemDiferenca[]; total: number; classe: string }) {
  if (total === 0) return null;
  return (
    <div className="mt-3">
      <h4 className={`text-xs font-semibold uppercase tracking-wide ${classe}`}>{titulo} ({total})</h4>
      <ul className="mt-1 divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white text-sm">
        {itens.map((item) => (
          <li key={item.chave} className="px-3 py-2">
            <p className="font-medium text-slate-800">{item.rotulo}</p>
            {item.detalhe && <p className="text-xs text-slate-500">{item.detalhe}</p>}
            {item.colunas && (
              <ul className="mt-1 space-y-0.5 text-xs text-slate-600">
                {item.colunas.map((c) => (
                  <li key={c.coluna}>
                    <span className="font-medium">{c.coluna}:</span> {c.antes} <span className="text-slate-400">→ hoje:</span> {c.depois}
                  </li>
                ))}
              </ul>
            )}
          </li>
        ))}
      </ul>
      {itens.length < total && <p className="mt-1 text-xs text-slate-500">Mostrando {itens.length} de {total}.</p>}
    </div>
  );
}

function CartaoTabela({ t }: { t: ResultadoTabela }) {
  const semMudanca = t.apagados + t.alterados + t.novos === 0;
  return (
    <details className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2">
      <summary className="flex cursor-pointer flex-wrap items-center gap-2 text-sm font-medium text-slate-800">
        <span>{t.rotulo}</span>
        {t.ausente ? (
          <span className="text-xs font-normal text-slate-500">(este backup não tem esta tabela)</span>
        ) : semMudanca ? (
          <span className="text-xs font-normal text-emerald-700">sem diferenças ({t.noBackup} no backup)</span>
        ) : (
          <>
            <Etiqueta n={t.apagados} texto="apagados" classe="bg-red-100 text-red-700" />
            <Etiqueta n={t.alterados} texto="alterados" classe="bg-amber-100 text-amber-700" />
            <Etiqueta n={t.novos} texto="novos" classe="bg-sky-100 text-sky-700" />
          </>
        )}
      </summary>
      {!t.ausente && !semMudanca && (
        <div className="pb-2">
          <p className="mt-2 text-xs text-slate-500">No backup: {t.noBackup} registros. Hoje: {t.hoje}.</p>
          <Lista titulo="Apagados desde o backup" itens={t.amostraApagados} total={t.apagados} classe="text-red-700" />
          <Lista titulo="Alterados desde o backup" itens={t.amostraAlterados} total={t.alterados} classe="text-amber-700" />
          <Lista titulo="Novos (criados depois do backup)" itens={t.amostraNovos} total={t.novos} classe="text-sky-700" />
        </div>
      )}
    </details>
  );
}

export default function PaginaRestauracao() {
  const { pode } = useSessao();
  const [backups, setBackups] = useState<RegistroBackup[] | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [escolhido, setEscolhido] = useState("");
  const [grupos, setGrupos] = useState<GrupoDados[]>(GRUPOS_DADOS.map((g) => g.id));
  const [comparando, setComparando] = useState(false);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [resultado, setResultado] = useState<ResultadoComparacao | null>(null);

  const [tentativa, setTentativa] = useState(0); // muda para recarregar a lista

  // Busca os backups; o estado só é alterado dentro das respostas (nunca direto no corpo do efeito)
  useEffect(() => {
    let ativo = true;
    listarBackups()
      .then((todos) => {
        if (!ativo) return;
        const lista = todos.filter((b) => b.situacao === "ok");
        setBackups(lista);
        setEscolhido((atual) => atual || lista[0]?.id || "");
        setErro(null);
      })
      .catch((e: unknown) => {
        if (ativo) setErro(e instanceof Error ? e.message : "Não foi possível carregar os backups.");
      });
    return () => {
      ativo = false;
    };
  }, [tentativa]);

  function alternar(id: GrupoDados) {
    setGrupos((atual) => (atual.includes(id) ? atual.filter((g) => g !== id) : [...atual, id]));
    setResultado(null);
  }

  async function aoComparar() {
    setComparando(true);
    setErroAcao(null);
    setResultado(null);
    try {
      setResultado(await compararBackup(escolhido, grupos));
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível comparar.");
    } finally {
      setComparando(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Compare um backup com os dados de hoje. Somente o Administrador tem acesso."
        />
        <AbasBackup />

        <p className="mb-4 rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
          Esta etapa só <strong>compara</strong>: nada é restaurado nem alterado. Mostra o que foi apagado, alterado ou
          criado depois do backup escolhido. CPF e segredos aparecem como &quot;(protegido)&quot;.
        </p>

        {!pode("backup.restaurar") ? (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            Somente o Administrador pode usar a restauração.
          </p>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os backups." mensagem={erro} onTentarNovamente={() => { setErro(null); setTentativa((n) => n + 1); }} />
        ) : !backups ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando os backups...</span>
            <Skeleton className="h-24" />
            <Skeleton className="h-24" />
          </div>
        ) : backups.length === 0 ? (
          <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">Ainda não há backups para comparar.</p>
        ) : (
          <div className="space-y-6">
            <section className="space-y-4 rounded-xl border border-slate-200 bg-white p-4">
              <div className="max-w-md space-y-1.5">
                <label htmlFor="rest-backup" className="text-xs font-medium text-slate-600">Backup</label>
                <select
                  id="rest-backup"
                  value={escolhido}
                  onChange={(e) => { setEscolhido(e.target.value); setResultado(null); }}
                  disabled={comparando}
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
                >
                  {backups.map((b) => (
                    <option key={b.id} value={b.id}>{rotuloBackup(b)}</option>
                  ))}
                </select>
              </div>

              <fieldset className="space-y-2">
                <legend className="text-xs font-medium text-slate-600">O que comparar</legend>
                <div className="grid gap-2 sm:grid-cols-2">
                  {GRUPOS_DADOS.map((g) => (
                    <label key={g.id} className="flex items-start gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm">
                      <input
                        type="checkbox"
                        checked={grupos.includes(g.id)}
                        onChange={() => alternar(g.id)}
                        disabled={comparando}
                        className="mt-0.5"
                      />
                      <span>
                        <span className="font-medium text-slate-800">{g.rotulo}</span>
                        <span className="block text-xs text-slate-500">{g.descricao}</span>
                      </span>
                    </label>
                  ))}
                </div>
              </fieldset>

              <button type="button" className={classeBotaoPrimario} onClick={() => void aoComparar()} disabled={comparando || !escolhido || grupos.length === 0}>
                {comparando ? "Comparando..." : "Comparar com os dados de hoje"}
              </button>
              {erroAcao && (
                <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroAcao}</p>
              )}
            </section>

            {resultado && (
              <section className="space-y-4" aria-live="polite">
                <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-700">
                  Backup de {dataHoraSalvador(new Date(resultado.backup.criado_em))}:{" "}
                  <strong>{resultado.totais.apagados}</strong> apagados, <strong>{resultado.totais.alterados}</strong> alterados e{" "}
                  <strong>{resultado.totais.novos}</strong> novos desde então.
                </p>
                {resultado.grupos.map((g) => (
                  <div key={g.id} className="space-y-2">
                    <h3 className="text-sm font-semibold text-slate-800">{g.rotulo}</h3>
                    {g.tabelas.map((t) => (
                      <CartaoTabela key={t.nome} t={t} />
                    ))}
                  </div>
                ))}
              </section>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
