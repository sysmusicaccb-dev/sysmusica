"use client";

/**
 * SysMúsica — Aparência do sistema: guarda as preferências do usuário, aplica o modo, a cor e o tamanho da
 * letra na página (atributos data-tema, data-cor e data-fonte da tag html, lidos por tema.css) e salva na
 * conta e neste aparelho. Fica dentro do SessaoProvider; "logado" avisa quando já dá para ler e salvar na conta.
 */
import "@/app/tema.css";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";
import { guardarPreferenciasLocais, lerPreferenciasLocais } from "../armazenamento";
import { atributosDoTema, lerPreferencias, PREFERENCIAS_PADRAO } from "../regras";
import { buscarPreferenciasDaConta, salvarPreferenciasNaConta } from "../services/preferencias";
import type { Preferencias } from "../tipos";

/** ocioso = nada foi salvo ainda; conta = salvo na conta; aparelho = salvo só neste aparelho. */
export type EstadoSalvamento = "ocioso" | "salvando" | "conta" | "aparelho";

interface ContextoPreferencias {
  preferencias: Preferencias;
  salvamento: EstadoSalvamento;
  definir: (novas: Preferencias) => Promise<void>;
  restaurarPadrao: () => Promise<void>;
}

const Contexto = createContext<ContextoPreferencias | null>(null);

export function usePreferencias(): ContextoPreferencias {
  const contexto = useContext(Contexto);
  if (!contexto) throw new Error("usePreferencias precisa estar dentro de <PreferenciasProvider>.");
  return contexto;
}

// O aparelho está no modo escuro? (acompanha a mudança enquanto o sistema está aberto)
const CONSULTA_ESCURO = "(prefers-color-scheme: dark)";

function assinarModoDoAparelho(aoMudar: () => void) {
  const lista = window.matchMedia(CONSULTA_ESCURO);
  lista.addEventListener("change", aoMudar);
  return () => lista.removeEventListener("change", aoMudar);
}

const lerModoDoAparelho = () => window.matchMedia(CONSULTA_ESCURO).matches;

export function PreferenciasProvider({ children, logado }: { children: ReactNode; logado: boolean }) {
  // Começa pela cópia deste aparelho (a tela não depende disso para ser desenhada: só a aparência muda)
  const [preferencias, setPreferencias] = useState<Preferencias>(
    () => lerPreferenciasLocais() ?? PREFERENCIAS_PADRAO
  );
  const [salvamento, setSalvamento] = useState<EstadoSalvamento>("ocioso");
  const aparelhoEscuro = useSyncExternalStore(assinarModoDoAparelho, lerModoDoAparelho, () => false);

  // Aplica a aparência na página
  useEffect(() => {
    const atributos = atributosDoTema(preferencias, aparelhoEscuro);
    const raiz = document.documentElement;
    raiz.setAttribute("data-tema", atributos.tema);
    raiz.setAttribute("data-cor", atributos.cor);
    raiz.setAttribute("data-fonte", atributos.fonte);
  }, [preferencias, aparelhoEscuro]);

  // Depois do login, busca as preferências da conta (valem sobre as do aparelho)
   
  useEffect(() => {
    if (!logado) return;
    let cancelado = false;
    void buscarPreferenciasDaConta()
      .then((daConta) => {
        if (cancelado || !daConta) return;
        setPreferencias(daConta);
        guardarPreferenciasLocais(daConta);
      })
      .catch(() => {
        // sem as da conta, o sistema segue com as do aparelho
      });
    return () => {
      cancelado = true;
    };
  }, [logado]);
   

  // Aplica na hora, guarda neste aparelho e tenta salvar na conta
  const definir = useCallback(
    async (novas: Preferencias) => {
      const limpas = lerPreferencias(novas);
      setPreferencias(limpas);
      guardarPreferenciasLocais(limpas);

      if (!logado) {
        setSalvamento("aparelho");
        return;
      }
      setSalvamento("salvando");
      try {
        await salvarPreferenciasNaConta(limpas);
        setSalvamento("conta");
      } catch {
        setSalvamento("aparelho");
      }
    },
    [logado]
  );

  const restaurarPadrao = useCallback(() => definir(PREFERENCIAS_PADRAO), [definir]);

  const valor = useMemo(
    () => ({ preferencias, salvamento, definir, restaurarPadrao }),
    [preferencias, salvamento, definir, restaurarPadrao]
  );

  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>;
}
