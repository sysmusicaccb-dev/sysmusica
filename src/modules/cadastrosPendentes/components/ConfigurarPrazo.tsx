"use client";

/**
 * SysMúsica — Painel "Prazo dos pedidos" (botão com ícone de engrenagem em Cadastros Pendentes).
 * Define por quantos dias um pedido do formulário público espera análise antes de vencer. O novo prazo vale
 * para os pedidos novos e para os que já estão pendentes. Se algum pendente já passou do novo prazo, a tela
 * avisa quantos são e pede confirmação antes de salvar. Só aparece para quem tem a permissão cadastros.configurar
 * (o banco confere de novo ao salvar).
 */
import { useCallback, useEffect, useState } from "react";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import { ATALHOS_PRAZO, dataDeVencimento, formatarDataCurta, validarPrazo } from "../prazo";
import { obterConfigPrazo, previaPrazo, salvarPrazo, type ConfigPrazo } from "../services/prazo";
import { avisarQueFilaMudou } from "../services/cadastrosPendentes";

export default function ConfigurarPrazo({ onSalvo }: { onSalvo: (mensagem: string) => void }) {
  const [config, setConfig] = useState<ConfigPrazo | null>(null);
  const [texto, setTexto] = useState("");
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erroCarga, setErroCarga] = useState<string | null>(null);
  const [salvando, setSalvando] = useState(false);
  const [erroSalvar, setErroSalvar] = useState<string | null>(null);
  const [vencerao, setVencerao] = useState<number | null>(null); // pedidos que passariam do novo prazo (pede confirmação)

  const carregar = useCallback(async () => {
    try {
      const atual = await obterConfigPrazo();
      setConfig(atual);
      setTexto(String(atual.prazo_dias));
      setErroCarga(null);
    } catch (e) {
      console.error("Falha ao carregar o prazo dos cadastros:", e);
      setErroCarga(e instanceof Error ? e.message : "Não foi possível carregar o prazo.");
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

  const validacao = validarPrazo(texto);
  const igualAoAtual = config !== null && validacao.ok && validacao.dias === config.prazo_dias;

  // forcar = true depois que a pessoa confirmou o aviso de pedidos que vencerão
  async function salvar(forcar: boolean) {
    if (!validacao.ok) {
      setErroSalvar(validacao.erro);
      return;
    }
    setSalvando(true);
    setErroSalvar(null);
    try {
      if (!forcar) {
        const qtd = await previaPrazo(validacao.dias);
        if (qtd > 0) {
          setVencerao(qtd);
          return;
        }
      }
      const resultado = await salvarPrazo(validacao.dias);
      avisarQueFilaMudou();
      onSalvo(
        `Prazo alterado para ${resultado.prazo_dias} dias.` +
          (resultado.vencerao_agora > 0
            ? ` ${resultado.vencerao_agora} pedido(s) já passaram do prazo e serão apagados na limpeza diária.`
            : "")
      );
    } catch (e) {
      setErroSalvar(e instanceof Error ? e.message : "Não foi possível salvar o prazo.");
    } finally {
      setSalvando(false);
    }
  }

  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="space-y-3">
        <span className="sr-only">Carregando o prazo...</span>
        <Skeleton className="h-12" />
        <Skeleton className="h-24" />
      </div>
    );
  }

  if (erroCarga || !config) {
    return (
      <div role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
        {erroCarga ?? "Não foi possível carregar o prazo."}{" "}
        <button
          type="button"
          className="font-semibold underline"
          onClick={() => {
            setCarregando(true);
            void carregar();
          }}
        >
          Tentar novamente
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      <div className="space-y-2">
        <label htmlFor="prazo-pedidos" className="text-sm font-medium text-slate-800">
          Prazo para analisar cada pedido (em dias)
        </label>
        <input
          id="prazo-pedidos"
          type="text"
          inputMode="numeric"
          maxLength={3}
          value={texto}
          onChange={(evento) => {
            setTexto(evento.target.value.replace(/\D/g, ""));
            setErroSalvar(null);
          }}
          aria-describedby="ajuda-prazo"
          className="w-32 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm tabular-nums text-slate-900 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
        />
        <p id="ajuda-prazo" className="text-xs text-slate-500">
          De {config.minimo} a {config.maximo} dias. Prazo atual: <strong>{config.prazo_dias} dias</strong> (padrão: {config.padrao}).
        </p>
        <div className="flex flex-wrap gap-2" role="group" aria-label="Prazos sugeridos">
          {ATALHOS_PRAZO.map((dias) => (
            <button
              key={dias}
              type="button"
              onClick={() => {
                setTexto(String(dias));
                setErroSalvar(null);
              }}
              className={cn(
                "rounded-full border px-3 py-1 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                texto === String(dias)
                  ? "border-brand-600 bg-brand-50 text-brand-700"
                  : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
              )}
            >
              {dias} dias
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-2 rounded-xl bg-slate-50 p-3 text-sm text-slate-700">
        {validacao.ok && (
          <p>
            Um pedido enviado <strong>hoje</strong> vai vencer em <strong>{formatarDataCurta(dataDeVencimento(validacao.dias))}</strong>.
          </p>
        )}
        <p>O prazo é contado a partir do envio de cada pedido e vale também para os que já estão na fila de pendentes.</p>
        <p>Pedidos já vencidos, aprovados ou recusados não mudam.</p>
        <p>Ao vencer, o pedido sai de Pendentes, as fotos e os dados enviados são apagados e a pessoa precisa preencher o formulário de novo.</p>
      </div>

      {(erroSalvar || (!validacao.ok && texto !== "")) && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroSalvar ?? (!validacao.ok ? validacao.erro : "")}
        </p>
      )}

      <Button onClick={() => void salvar(false)} disabled={salvando || !validacao.ok || igualAoAtual} className="w-full">
        {salvando ? "Salvando..." : igualAoAtual ? "Este já é o prazo atual" : "Salvar prazo"}
      </Button>

      <ConfirmDialog
        aberto={vencerao !== null}
        titulo="Alguns pedidos vão vencer"
        mensagem={
          <p>
            Com o prazo de <strong>{validacao.ok ? validacao.dias : "?"} dias</strong>, <strong>{vencerao}</strong> pedido(s) pendente(s) já passaram
            do limite e vencem na próxima limpeza diária. Os dados e as fotos deles serão apagados e não poderão ser
            recuperados. Deseja continuar?
          </p>
        }
        textoConfirmar="Salvar mesmo assim"
        variante="perigo"
        processando={salvando}
        onConfirmar={() => {
          setVencerao(null);
          void salvar(true);
        }}
        onCancelar={() => setVencerao(null)}
      />
    </div>
  );
}
