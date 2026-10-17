"use client";

/**
 * SysMúsica — Sessão e permissões do usuário logado (contexto para todo o sistema).
 *
 * Guarda a sessão do Supabase Auth e a "conta" (nome, grupo e lista de permissões, vinda da função
 * minha_conta do banco). A tela usa pode("membros.editar") para mostrar ou esconder botões e
 * menus; a regra de verdade é aplicada pelo banco (RLS), então esconder um botão nunca é a
 * única proteção.
 */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import type { CodigoPermissao } from "@/lib/permissoes";

export interface Conta {
  nome: string;
  email: string;
  grupo: string | null;
  ativo: boolean;
  permissoes: string[];
}

interface ContextoSessao {
  carregando: boolean; // ainda verificando a sessão salva e as permissões
  sessao: Session | null;
  conta: Conta | null;
  erroConta: string | null;
  pode: (permissao: CodigoPermissao) => boolean;
  sair: () => Promise<void>;
}

const Contexto = createContext<ContextoSessao | null>(null);

/** Acesso à sessão e às permissões. Só funciona dentro de <SessaoProvider>. */
export function useSessao(): ContextoSessao {
  const contexto = useContext(Contexto);
  if (!contexto) throw new Error("useSessao precisa estar dentro de <SessaoProvider>.");
  return contexto;
}

export default function SessaoProvider({ children }: { children: ReactNode }) {
  const [sessao, setSessao] = useState<Session | null>(null);
  const [conta, setConta] = useState<Conta | null>(null);
  const [erroConta, setErroConta] = useState<string | null>(null);
  const [sessaoPronta, setSessaoPronta] = useState(false); // já sabemos se existe sessão salva?
  const [contaPronta, setContaPronta] = useState(false); // já buscamos o grupo e as permissões?

  // Busca nome, grupo e permissões do usuário logado (função minha_conta do banco)
  const carregarConta = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc("minha_conta").maybeSingle();
      if (error) throw new Error(error.message);
      setConta((data as Conta | null) ?? null);
      setErroConta(null);
    } catch (e) {
      console.error("Falha ao carregar a conta:", e);
      setConta(null);
      setErroConta("Não foi possível carregar suas permissões. Tente novamente.");
    } finally {
      setContaPronta(true);
    }
  }, []);

  // Acompanha a sessão: o Supabase avisa a sessão salva no navegador (evento INITIAL_SESSION)
  // logo ao se inscrever e, depois, cada login, logout e renovação de token.
  useEffect(() => {
    const { data: assinatura } = supabase.auth.onAuthStateChange((_evento, novaSessao) => {
      setSessao(novaSessao);
      setSessaoPronta(true);

      if (!novaSessao) {
        // Saiu da conta: limpa tudo (o próximo login volta a mostrar "carregando")
        setConta(null);
        setContaPronta(false);
        return;
      }

      // Não se deve chamar o Supabase de dentro deste callback (pode travar): adia para o próximo ciclo
      window.setTimeout(() => {
        void carregarConta();
      }, 0);
    });
    return () => assinatura.subscription.unsubscribe();
  }, [carregarConta]);

  // Conjunto de permissões (vazio quando a conta está inativa)
  const permissoes = useMemo(() => new Set<string>(conta?.ativo ? conta.permissoes : []), [conta]);
  const pode = useCallback((permissao: CodigoPermissao) => permissoes.has(permissao), [permissoes]);

  const sair = useCallback(async () => {
    await supabase.auth.signOut(); // o callback acima limpa a sessão e a conta
  }, []);

  const carregando = !sessaoPronta || (sessao !== null && !contaPronta);

  const valor = useMemo(
    () => ({ carregando, sessao, conta, erroConta, pode, sair }),
    [carregando, sessao, conta, erroConta, pode, sair]
  );

  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>;
}
