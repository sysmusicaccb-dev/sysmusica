"use client";

/**
 * SysMúsica — Página /instrumentos (instrumentos e famílias).
 *
 * Qualquer pessoa vê a classificação (instrumento -> família). Somente um ADMINISTRADOR
 * (usuário do Supabase Auth com app_metadata.papel = "admin") pode corrigir a família:
 *  - a tela esconde os selects de edição para quem não é admin;
 *  - o banco impõe a regra de verdade (política admin_update_instrumentos em supabase/schema.sql).
 *
 * Como criar um administrador: veja o cabeçalho do supabase/schema.sql.
 */
import { useCallback, useEffect, useState, type FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import type { Familia, Instrumento } from "@/types/database";

// Mesma identidade visual dos demais formulários
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none " +
  "focus:ring-2 focus:ring-indigo-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function InstrumentosPage() {
  // ---------- Dados ----------
  const [instrumentos, setInstrumentos] = useState<Instrumento[]>([]);
  const [familias, setFamilias] = useState<Familia[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // ---------- Sessão (login do administrador) ----------
  const [sessao, setSessao] = useState<Session | null>(null);
  const [carregandoSessao, setCarregandoSessao] = useState(true);
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [entrando, setEntrando] = useState(false);
  const [erroLogin, setErroLogin] = useState<string | null>(null);

  // ---------- Edição da família ----------
  const [salvandoId, setSalvandoId] = useState<string | null>(null);
  const [erroEdicao, setErroEdicao] = useState<string | null>(null);

  // O papel vem do token do login (app_metadata só pode ser definido pelo painel/SQL do Supabase)
  const ehAdmin = sessao?.user.app_metadata?.papel === "admin";

  // Busca instrumentos e famílias em paralelo
  const buscarDados = useCallback(async () => {
    try {
      const [resInstrumentos, resFamilias] = await Promise.all([
        supabase.from("instrumentos").select("*").order("nome", { ascending: true }),
        supabase.from("familias").select("*").order("nome", { ascending: true }),
      ]);

      const erroBanco = resInstrumentos.error ?? resFamilias.error;
      if (erroBanco) throw new Error(erroBanco.message);

      setInstrumentos((resInstrumentos.data ?? []) as Instrumento[]);
      setFamilias((resFamilias.data ?? []) as Familia[]);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro desconhecido ao buscar os dados.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void buscarDados();
  }, [buscarDados]);

  // Acompanha a sessão: o Supabase avisa a sessão salva no navegador (evento INITIAL_SESSION)
  // logo ao se inscrever e, depois, cada login/logout.
  useEffect(() => {
    const { data: assinatura } = supabase.auth.onAuthStateChange((_evento, novaSessao) => {
      setSessao(novaSessao);
      setCarregandoSessao(false);
    });
    return () => assinatura.subscription.unsubscribe();
  }, []);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void buscarDados();
  }

  async function entrar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErroLogin(null);
    setEntrando(true);
    try {
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password: senha });
      if (error) {
        throw new Error(
          error.message === "Invalid login credentials" ? "E-mail ou senha inválidos." : error.message
        );
      }
      setSenha(""); // a sessão chega pelo onAuthStateChange
    } catch (e) {
      setErroLogin(e instanceof Error ? e.message : "Não foi possível entrar.");
    } finally {
      setEntrando(false);
    }
  }

  async function sair() {
    await supabase.auth.signOut();
    setErroEdicao(null);
  }

  // Corrige a família de um instrumento (só funciona para administrador: o banco confere)
  async function alterarFamilia(instrumento: Instrumento, novaFamiliaId: string) {
    setErroEdicao(null);
    setSalvandoId(instrumento.id);
    try {
      const { data, error } = await supabase
        .from("instrumentos")
        .update({ familia_id: novaFamiliaId || null })
        .eq("id", instrumento.id)
        .select("id");
      if (error) throw new Error(error.message);
      // Quando o RLS nega, o update não dá erro: apenas não altera nenhuma linha
      if (!data || data.length === 0) {
        throw new Error("Sem permissão para alterar este instrumento (é preciso ser administrador).");
      }

      // Atualiza a tela sem recarregar tudo
      setInstrumentos((anterior) =>
        anterior.map((item) =>
          item.id === instrumento.id ? { ...item, familia_id: novaFamiliaId || null } : item
        )
      );
    } catch (e) {
      setErroEdicao(e instanceof Error ? e.message : "Não foi possível salvar a alteração.");
    } finally {
      setSalvandoId(null);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <header className="mb-8">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Instrumentos</h1>
          <p className="mt-1 text-sm text-slate-600">
            Família de cada instrumento, definida automaticamente no cadastro.
            {!carregando && !erro && ` ${instrumentos.length} instrumento(s).`}
          </p>
        </header>

        <div className="grid gap-6 lg:grid-cols-3">
          {/* Coluna esquerda: acesso administrativo */}
          <section className="lg:col-span-1">
            <div className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Acesso administrativo</h2>
                <p className="text-sm text-slate-500">
                  Somente administradores podem corrigir a família de um instrumento.
                </p>
              </div>

              {carregandoSessao ? (
                <div role="status" aria-live="polite" className="space-y-3">
                  <span className="sr-only">Verificando acesso...</span>
                  <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
                  <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
                </div>
              ) : !sessao ? (
                // Sem login: formulário de entrada
                <form onSubmit={entrar} className="space-y-3">
                  <div className="space-y-1.5">
                    <label htmlFor="email" className="text-sm font-medium text-slate-700">
                      E-mail
                    </label>
                    <input
                      id="email"
                      type="email"
                      required
                      autoComplete="username"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      disabled={entrando}
                      className={classeInput}
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label htmlFor="senha" className="text-sm font-medium text-slate-700">
                      Senha
                    </label>
                    <input
                      id="senha"
                      type="password"
                      required
                      autoComplete="current-password"
                      value={senha}
                      onChange={(e) => setSenha(e.target.value)}
                      disabled={entrando}
                      className={classeInput}
                    />
                  </div>

                  {erroLogin && (
                    <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
                      {erroLogin}
                    </p>
                  )}

                  <button
                    type="submit"
                    disabled={entrando}
                    className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {entrando ? "Entrando..." : "Entrar"}
                  </button>
                </form>
              ) : (
                // Com login: mostra quem é e se tem permissão
                <div className="space-y-3">
                  <p className="text-sm text-slate-600">
                    Conectado como <span className="font-medium text-slate-900">{sessao.user.email}</span>
                  </p>
                  {ehAdmin ? (
                    <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
                      Você é administrador: use a coluna Família ao lado para corrigir classificações.
                    </p>
                  ) : (
                    <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
                      Esta conta não tem permissão de administrador, então a tabela fica somente leitura.
                    </p>
                  )}
                  <button
                    type="button"
                    onClick={() => void sair()}
                    className="w-full rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
                  >
                    Sair
                  </button>
                </div>
              )}
            </div>
          </section>

          {/* Coluna direita: tabela de instrumentos e famílias */}
          <section className="min-w-0 lg:col-span-2">
            {carregando ? (
              // Carregando: skeleton
              <div
                role="status"
                aria-live="polite"
                className="space-y-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
              >
                <span className="sr-only">Carregando instrumentos...</span>
                {[0, 1, 2, 3, 4].map((i) => (
                  <div key={i} className="h-10 animate-pulse rounded bg-slate-100" />
                ))}
              </div>
            ) : erro ? (
              // Erro na comunicação com o banco
              <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-6">
                <p className="font-semibold text-red-800">Não foi possível carregar os instrumentos.</p>
                <p className="mt-1 text-sm text-red-700">{erro}</p>
                <button
                  type="button"
                  onClick={tentarNovamente}
                  className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500"
                >
                  Tentar novamente
                </button>
              </div>
            ) : instrumentos.length === 0 ? (
              // Nenhum instrumento
              <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
                <p className="font-medium text-slate-700">Nenhum instrumento cadastrado ainda.</p>
                <p className="mt-1 text-sm text-slate-500">
                  Os instrumentos são criados automaticamente no cadastro de membros.
                </p>
              </div>
            ) : (
              <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
                {erroEdicao && (
                  <p role="alert" className="border-b border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {erroEdicao}
                  </p>
                )}
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-slate-200 text-sm">
                    <thead className="bg-slate-50">
                      <tr>
                        <th
                          scope="col"
                          className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500"
                        >
                          Instrumento
                        </th>
                        <th
                          scope="col"
                          className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500"
                        >
                          Família
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {instrumentos.map((instrumento) => {
                        const familia = familias.find((item) => item.id === instrumento.familia_id);
                        return (
                          <tr key={instrumento.id} className="transition hover:bg-slate-50">
                            <td className="px-4 py-3 font-medium text-slate-900">{instrumento.nome}</td>
                            <td className="px-4 py-3">
                              {ehAdmin ? (
                                // Administrador: pode corrigir a família
                                <select
                                  aria-label={`Família de ${instrumento.nome}`}
                                  value={instrumento.familia_id ?? ""}
                                  onChange={(e) => void alterarFamilia(instrumento, e.target.value)}
                                  disabled={salvandoId === instrumento.id}
                                  className="w-full max-w-[14rem] rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-900 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-200 disabled:opacity-60"
                                >
                                  <option value="">Não classificada</option>
                                  {familias.map((item) => (
                                    <option key={item.id} value={item.id}>
                                      {item.nome}
                                    </option>
                                  ))}
                                </select>
                              ) : familia ? (
                                <span className="rounded-full bg-indigo-50 px-2 py-0.5 text-xs font-medium text-indigo-700">
                                  {familia.nome}
                                </span>
                              ) : (
                                <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700">
                                  Não classificada
                                </span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </section>
        </div>
      </div>
    </main>
  );
}
