"use client";

/**
 * Sysmusica — Topo azul (centro): "Próximo evento" com a data e a hora do evento mais próximo de agora.
 * Só aparece para quem pode ver o Painel ao Vivo (é de onde vêm os eventos) e quando existe um evento.
 * (O relógio com a data e a hora atuais é o RelogioDoTopo, ao lado da engrenagem.)
 * Nenhuma escolha global: é apenas informativo.
 */
import { useEffect, useMemo, useState } from "react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { listarEventosDoPainel } from "@/modules/painel/services/painel";
import {
  TROCA_EVENTO_MS,
  proximoIndiceDoCarrossel,
  proximosEventosDoTopo,
  resumosDosEventos,
  type ResumoEventoTopo,
} from "./topo";

export default function EventoDoTopo() {
  const { pode } = useSessao();
  const permitido = pode("painel.visualizar");
  const [resumos, setResumos] = useState<ResumoEventoTopo[]>([]);
  // Hora atual (para esconder o evento assim que ele passa): começa vazia e confere a cada minuto
  const [agora, setAgora] = useState<Date | null>(null);

  useEffect(() => {
    const primeira = setTimeout(() => setAgora(new Date()), 0);
    const temporizador = setInterval(() => setAgora(new Date()), 60_000);
    return () => {
      clearTimeout(primeira);
      clearInterval(temporizador);
    };
  }, []);

  useEffect(() => {
    if (!permitido) return;
    let cancelado = false;
    listarEventosDoPainel()
      .then((lista) => {
        if (!cancelado) setResumos(resumosDosEventos(lista));
      })
      .catch(() => {
        /* o topo é só informativo: sem evento, o bloco simplesmente não aparece */
      });
    return () => {
      cancelado = true;
    };
  }, [permitido]);

  // Só entram eventos que ainda vão acontecer (do mais próximo ao mais distante); o que passou sai sozinho
  const futuros = useMemo(() => (agora ? proximosEventosDoTopo(resumos, agora) : []), [resumos, agora]);
  const total = futuros.length;
  const [indice, setIndice] = useState(0);
  const [pausado, setPausado] = useState(false);

  // Com mais de um evento, passa para o seguinte a cada 5 segundos, em loop. Mouse em cima: pausa para ler.
  useEffect(() => {
    if (total < 2 || pausado) return;
    const ciclo = setInterval(() => setIndice((atual) => proximoIndiceDoCarrossel(atual, total)), TROCA_EVENTO_MS);
    return () => clearInterval(ciclo);
  }, [total, pausado]);

  if (!permitido || total === 0) return null;
  const posicao = indice % total; // se a lista encolher, nunca aponta para um evento que não existe
  const resumo = futuros[posicao];

  // Texto maior e em destaque, com o rótulo para não ser confundido com a hora atual
  return (
    <p
      key={posicao}
      onMouseEnter={() => setPausado(true)}
      onMouseLeave={() => setPausado(false)}
      className="hidden max-w-full animate-evento-topo truncate text-lg font-semibold tracking-wide motion-reduce:animate-none md:block"
      aria-label={posicao === 0 ? "Próximo evento" : "Evento seguinte"}
    >
      <span className="font-medium text-blue-100">{posicao === 0 ? "Próximo evento:" : "Em seguida:"}</span>{" "}
      {resumo.titulo} · {formatarDiaDoEvento(resumo.dataIso)} às {formatarHoraDoEvento(resumo.dataIso)}
      {total > 1 && (
        <span className="ml-2 text-sm font-medium text-blue-200">
          ({posicao + 1}/{total})
        </span>
      )}
    </p>
  );
}
