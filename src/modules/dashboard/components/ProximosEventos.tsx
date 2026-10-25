/**
 * Sysmusica — Cartão "Próximos eventos" do dashboard (componente de apresentação).
 * Recebe a lista pronta; se estiver vazia, orienta o usuário a cadastrar um evento.
 */
import Link from "next/link";
import { CalendarDays } from "lucide-react";
import Badge from "@/components/ui/Badge";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { formatarDataHora, partesDaData } from "@/lib/datas";
import type { Evento } from "@/types/database";

interface ProximosEventosProps {
  eventos: Evento[];
}

// Cor do selo conforme o tipo do evento (tipos desconhecidos usam o neutro)
function varianteTipo(tipo: string): "marca" | "alerta" | "neutro" {
  const normalizado = tipo.trim().toLowerCase();
  if (normalizado === "ensaio") return "marca";
  if (normalizado === "culto") return "alerta";
  return "neutro";
}

export default function ProximosEventos({ eventos }: ProximosEventosProps) {
  return (
    <Card icone={CalendarDays} titulo="Próximos eventos" descricao="Eventos agendados a partir de agora.">
      {eventos.length === 0 ? (
        <EmptyState
          titulo="Nenhum evento agendado"
          descricao="Cadastre o próximo ensaio ou culto para ele aparecer aqui."
          acao={
            <Link
              href="/eventos"
              className="inline-flex rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-brand-700"
            >
              Cadastrar evento
            </Link>
          }
        />
      ) : (
        <ul className="divide-y divide-slate-100">
          {eventos.map((evento) => {
            const { dia, mes } = partesDaData(evento.data_evento);

            return (
              <li key={evento.id} className="flex items-center gap-4 py-3 first:pt-0 last:pb-0">
                {/* Bloco de data: dia e mês abreviado */}
                <div className="flex h-12 w-12 shrink-0 flex-col items-center justify-center rounded-xl bg-brand-50 text-brand-700">
                  <span className="text-base font-bold leading-none">{dia}</span>
                  <span className="mt-0.5 text-[10px] font-medium uppercase">{mes}</span>
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium text-slate-900">{evento.local}</p>
                  <p className="text-xs text-slate-500">{formatarDataHora(evento.data_evento)}</p>
                </div>
                <Badge variante={varianteTipo(evento.tipo)}>{evento.tipo}</Badge>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}
