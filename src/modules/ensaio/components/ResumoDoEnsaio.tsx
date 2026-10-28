"use client";

/**
 * Sysmusica — Resumo lateral do ensaio ("Resumo do Ensaio"): evento, quem atendeu, palavra, encarregados e hinos,
 * em tempo real, conforme a pessoa preenche o formulário. Mostra só o que o perfil do tipo de evento usa.
 */
import type { ReactNode } from "react";
import { BookOpen, CalendarDays, Clock, MapPin, Music, User, Users } from "lucide-react";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import { rotuloDoCargoEncarregado, tituloBlocoEncarregados, type ConfigEnsaio } from "../perfilConfig";
import { rotuloDoCargo } from "../regras";
import type { EstadoEnsaioCfg } from "../regrasPerfil";
import type { EventoDoEnsaio } from "../tipos";
import { localDoEvento } from "../apresentacao";
import { partesDoHino } from "../hinosApresentacao";

interface ResumoDoEnsaioProps {
  estado: EstadoEnsaioCfg;
  config: ConfigEnsaio;
  hinos: Hino[];
  evento: EventoDoEnsaio;
}

const LIMITE_HINOS = 12; // quantos hinos listar no resumo (o restante vira "+ N")

function Linha({ icone: Icone, children }: { icone: typeof User; children: ReactNode }) {
  return (
    <li className="flex items-start gap-2.5">
      <Icone className="mt-0.5 h-4 w-4 shrink-0 text-slate-600" aria-hidden="true" />
      <div className="min-w-0 flex-1 text-slate-800">{children}</div>
    </li>
  );
}

export default function ResumoDoEnsaio({ estado, config, hinos, evento }: ResumoDoEnsaioProps) {
  const abertura = hinos.find((h) => h.id === estado.hinoAberturaId);
  const preenchidos = estado.encarregados.filter((e) => e.nome.trim() !== "");
  const local = localDoEvento(evento);
  const hinosPorId = new Map(hinos.map((h) => [h.id, h] as const));
  const escolhidos = estado.hinosIds.slice(0, LIMITE_HINOS);
  const cargo = rotuloDoCargo(estado.atendeCargo) || "Quem atendeu";
  const modoAbertura = config.hino_abertura.modo;
  // Texto do hino de abertura conforme a pergunta: sem resposta "—", Não "Não houve", Sim o hino escolhido
  const textoAbertura =
    modoAbertura === "pergunta" && estado.houveAbertura === "NAO"
      ? "Não houve"
      : abertura
        ? rotuloCompleto(abertura)
        : "—";

  return (
    <section aria-label="Resumo do ensaio">
      <h2 className="mb-2 text-base font-bold text-slate-900">Resumo do Ensaio</h2>
      <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <p className="text-base font-bold text-slate-900">{evento.tipo}</p>
        {local && <p className="text-xs font-medium tracking-wide text-slate-500">{local}</p>}

        <ul className="mt-3 space-y-2 text-sm">
          <Linha icone={CalendarDays}>{formatarDiaDoEvento(evento.data_evento)}</Linha>
          <Linha icone={Clock}>{formatarHoraDoEvento(evento.data_evento)}</Linha>
          {local && <Linha icone={MapPin}>{local}</Linha>}
          {config.quem_atendeu.ativo && (
            <Linha icone={User}>
              {cargo}: {estado.atendeNome.trim() || "—"}
            </Linha>
          )}
          {config.palavra.ativo && (
            <Linha icone={BookOpen}>
              Palavra: {estado.palavra.trim() ? <span className="break-words">{estado.palavra.trim().slice(0, 120)}{estado.palavra.trim().length > 120 ? "…" : ""}</span> : "—"}
            </Linha>
          )}
          {config.encarregados.ativo && (
            <Linha icone={Users}>
              <p>
                {tituloBlocoEncarregados(config.encarregados.cargos)} ({preenchidos.length}):
              </p>
              {preenchidos.length === 0 ? (
                <p>—</p>
              ) : (
                <ol className="mt-1 space-y-0.5">
                  {preenchidos.map((e, i) => (
                    <li key={i} className="flex gap-2">
                      <span className="w-4 shrink-0 tabular-nums text-slate-500">{i + 1}.</span>
                      <span className="min-w-0 break-words">
                        {e.nome.trim()}
                        {config.encarregados.cargos.length > 1 && e.cargo ? ` – ${rotuloDoCargoEncarregado(e.cargo)}` : ""}
                        {e.cidadeUf ? ` (${e.cidadeUf})` : ""}
                      </span>
                    </li>
                  ))}
                </ol>
              )}
            </Linha>
          )}
          {(modoAbertura !== "nao_usa" || config.hinos_executados.ativo) && (
            <Linha icone={Music}>
              {modoAbertura !== "nao_usa" && <p>Hino de abertura: {textoAbertura}</p>}
              {config.hinos_executados.ativo && (
                <>
                  <p className="mt-1 font-semibold">Hinos executados ({estado.hinosIds.length}):</p>
                  {escolhidos.length === 0 ? (
                    <p>—</p>
                  ) : (
                    <ul className="mt-1 space-y-0.5 text-xs">
                      {escolhidos.map((id) => {
                        const hino = hinosPorId.get(id);
                        const partes = hino ? partesDoHino(hino) : null;
                        return (
                          <li key={id} className="break-words">
                            {partes ? `${partes.numero} – ${partes.titulo}` : "Hino removido do cadastro"}
                          </li>
                        );
                      })}
                      {estado.hinosIds.length > LIMITE_HINOS && <li>+ {estado.hinosIds.length - LIMITE_HINOS} hino(s)</li>}
                    </ul>
                  )}
                </>
              )}
            </Linha>
          )}
        </ul>
      </div>
    </section>
  );
}
