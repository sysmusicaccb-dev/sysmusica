"use client";

/**
 * Sysmusica — Card "Cartões de identificação" do Dashboard.
 * Mostra quantos cartões já venceram, quantos vencem nos próximos 30 dias e quantos não têm validade
 * informada, com um atalho para a lista. Só aparece para quem tem a permissão cartoes.visualizar; os
 * números vêm do banco já filtrados pela abrangência de quem está logado. Se a busca falhar, o erro
 * fica só neste card (o resto do Dashboard continua normal).
 */
import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import Card from "@/components/ui/Card";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { PRAZO_PADRAO_DIAS } from "../regras";
import { buscarResumoCartoes } from "../services/cartoes";
import type { ResumoCartoes } from "../tipos";

function Numero({ valor, rotulo, classe }: { valor: number; rotulo: string; classe: string }) {
  return (
    <div className="rounded-xl border border-slate-200 p-3 text-center">
      <p className={cn("text-2xl font-bold tabular-nums", classe)}>{valor}</p>
      <p className="mt-0.5 text-xs text-slate-600">{rotulo}</p>
    </div>
  );
}

export default function CartoesAVencerCard() {
  const { pode } = useSessao();
  const permitido = pode("cartoes.visualizar");

  const [resumo, setResumo] = useState<ResumoCartoes | null>(null);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setResumo(await buscarResumoCartoes(PRAZO_PADRAO_DIAS));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar o resumo dos cartões:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os cartões.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    if (!permitido) return;
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [permitido, carregar]);

  if (!permitido) return null;

  const tudoEmDia = resumo !== null && resumo.vencidos === 0 && resumo.a_vencer === 0 && resumo.sem_validade === 0;

  return (
    <Card
      titulo="Cartões de identificação"
      descricao={`Vencidos e a vencer nos próximos ${PRAZO_PADRAO_DIAS} dias.`}
    >
      {carregando ? (
        <div role="status" aria-live="polite">
          <span className="sr-only">Carregando os cartões...</span>
          <Skeleton className="h-20 rounded-xl" />
        </div>
      ) : erro || !resumo ? (
        <div role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro ?? "Não foi possível carregar os cartões."}{" "}
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
      ) : (
        <div className="space-y-3">
          {tudoEmDia ? (
            <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
              Nenhum cartão vencido, a vencer ou sem validade informada.
            </p>
          ) : (
            <div className="grid grid-cols-3 gap-2">
              <Numero valor={resumo.vencidos} rotulo="Vencidos" classe="text-red-600" />
              <Numero valor={resumo.a_vencer} rotulo="A vencer" classe="text-amber-600" />
              <Numero valor={resumo.sem_validade} rotulo="Sem validade" classe="text-slate-600" />
            </div>
          )}
          <Link href="/cartoes" className="inline-block text-sm font-semibold text-brand-700 hover:underline">
            Ver a lista completa
          </Link>
        </div>
      )}
    </Card>
  );
}
