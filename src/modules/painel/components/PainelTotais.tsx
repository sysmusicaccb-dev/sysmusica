/**
 * Sysmusica — Painel de Totais (visual do protótipo): cabeçalho do evento, quatro cartões de totais,
 * gráfico de rosca (participantes por grupo), gráficos de barras (músicos e organistas por categoria),
 * tabelas por categoria e participantes por família e instrumento.
 * Componente de apresentação: recebe os números prontos do banco. Os gráficos são desenhados com SVG e CSS
 * (sem biblioteca) e cada gráfico tem a tabela com os mesmos números logo abaixo.
 * ATENÇÃO (tema escuro): nunca usar classes "bg-white/NN"; use cores sólidas ou rgb() entre colchetes.
 */
import { CalendarDays, Clock, Guitar, Keyboard, Music, Users, type LucideIcon } from "lucide-react";
import {
  dividirEmDuas,
  escalaDoGrafico,
  fatiasDaRosca,
  montarInstrumentos,
  type DadosPainelTotais,
} from "../detalhe";
import { agruparBlocos, formatarDiaDoEvento, formatarHoraDoEvento } from "../regras";
import type { BlocoResumo, LinhaPainel } from "../tipos";
import BotaoImprimirPainel from "./BotaoImprimirPainel";

// Cores de cada grupo (iguais nos cartões, na rosca e nos títulos)
const COR_MINISTERIO = "#2563eb";
const COR_MUSICOS = "#16a34a";
const COR_ORGANISTAS = "#f97316";

// Cor da bolinha de cada família
const COR_FAMILIA: Record<string, string> = {
  Cordas: "bg-amber-700",
  Madeiras: "bg-stone-700",
  Metais: "bg-yellow-500",
  Teclas: "bg-violet-500",
};

const classeCartao = "rounded-xl border border-slate-200 bg-white shadow-sm";

// ---------- Cartões de totais ----------

function CartaoTotal({
  icone: Icone,
  titulo,
  valor,
  fundo,
  cor,
}: {
  icone: LucideIcon;
  titulo: string;
  valor: number;
  fundo: string;
  cor: string;
}) {
  return (
    <section aria-label={titulo} className={`flex items-center gap-4 rounded-xl border px-4 py-4 shadow-sm ${fundo}`}>
      <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-white">
        <Icone className="h-8 w-8" style={{ color: cor }} aria-hidden="true" />
      </span>
      <div className="min-w-0">
        <p className="truncate text-sm font-semibold text-slate-800">{titulo}</p>
        <p className="text-4xl font-bold leading-tight tabular-nums text-slate-900">{valor}</p>
      </div>
    </section>
  );
}

// ---------- Rosca: participantes por grupo ----------

const RAIO = 70;
const CIRCUNFERENCIA = 2 * Math.PI * RAIO;

function GraficoRosca({ blocos }: { blocos: BlocoResumo[] }) {
  const cores = [COR_MINISTERIO, COR_MUSICOS, COR_ORGANISTAS];
  const total = blocos.reduce((soma, bloco) => soma + bloco.total, 0);
  const fatias = fatiasDaRosca(
    blocos.map((bloco) => ({ rotulo: bloco.rotulo, qtd: bloco.total })),
    CIRCUNFERENCIA
  );
  const resumo = fatias.map((f) => `${f.rotulo} ${f.qtd} (${f.percentual})`).join(", ");

  return (
    <section aria-label="Participantes por grupo" className={`${classeCartao} p-4`}>
      <h3 className="flex items-center gap-2 text-sm font-semibold text-slate-900">
        <Users className="h-4 w-4 text-slate-600" aria-hidden="true" />
        Participantes por grupo
      </h3>
      <div className="mt-3 flex flex-wrap items-center justify-center gap-x-6 gap-y-3">
        <svg viewBox="0 0 200 200" className="h-40 w-40 shrink-0" role="img" aria-label={`Participantes por grupo: ${resumo}`}>
          {/* Fundo cinza (aparece inteiro quando ninguém entrou ainda) */}
          <circle cx="100" cy="100" r={RAIO} fill="none" stroke="#e2e8f0" strokeWidth="28" />
          {fatias.map((fatia, i) =>
            fatia.comprimento > 0 ? (
              <circle
                key={fatia.rotulo}
                cx="100"
                cy="100"
                r={RAIO}
                fill="none"
                stroke={cores[i]}
                strokeWidth="28"
                strokeDasharray={`${fatia.comprimento} ${CIRCUNFERENCIA - fatia.comprimento}`}
                strokeDashoffset={-fatia.deslocamento}
                transform="rotate(-90 100 100)"
              />
            ) : null
          )}
          <text x="100" y="104" textAnchor="middle" className="fill-slate-900 text-[34px] font-bold">
            {total}
          </text>
          <text x="100" y="126" textAnchor="middle" className="fill-slate-600 text-[13px]">
            Total
          </text>
        </svg>
        <ul className="space-y-1.5 text-sm">
          {fatias.map((fatia, i) => (
            <li key={fatia.rotulo} className="flex items-center gap-2 text-slate-700">
              <span className="h-3 w-3 shrink-0 rounded-full" style={{ backgroundColor: cores[i] }} aria-hidden="true" />
              <span className="min-w-[5.5rem]">{fatia.rotulo}</span>
              <span className="tabular-nums text-slate-900">
                {fatia.qtd} <span className="text-slate-500">({fatia.percentual})</span>
              </span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

// ---------- Barras: categorias de um grupo ----------

function GraficoBarras({
  titulo,
  icone: Icone,
  cor,
  linhas,
}: {
  titulo: string;
  icone: LucideIcon;
  cor: string;
  linhas: LinhaPainel[];
}) {
  const { topo, marcas } = escalaDoGrafico(linhas.map((linha) => linha.qtd));
  const resumo = linhas.map((linha) => `${linha.rotulo} ${linha.qtd}`).join(", ");

  return (
    <section aria-label={titulo} className={`${classeCartao} p-4`}>
      <h3 className="flex items-center gap-2 text-sm font-semibold text-slate-900">
        <Icone className="h-4 w-4" style={{ color: cor }} aria-hidden="true" />
        {titulo}
      </h3>
      {linhas.length === 0 ? (
        <p className="mt-6 text-center text-sm text-slate-500">Nenhuma categoria para mostrar.</p>
      ) : (
        <div className="mt-3 flex gap-2" role="img" aria-label={`${titulo}: ${resumo}`}>
          {/* Eixo vertical */}
          <div className="relative h-40 w-6 shrink-0 pt-6">
            <div className="relative h-full">
              {marcas.map((marca) => (
                <span
                  key={marca}
                  className="absolute right-0 -translate-y-1/2 text-[11px] tabular-nums text-slate-500"
                  style={{ top: `${100 - (marca / topo) * 100}%` }}
                >
                  {marca}
                </span>
              ))}
            </div>
          </div>
          <div className="min-w-0 flex-1">
            <div className="relative h-40 pt-6">
              <div className="relative h-full border-b border-slate-300">
                {marcas.slice(1).map((marca) => (
                  <div
                    key={marca}
                    className="absolute inset-x-0 border-t border-slate-200"
                    style={{ top: `${100 - (marca / topo) * 100}%` }}
                  />
                ))}
                <div className="absolute inset-0 flex items-end justify-around gap-2 px-1">
                  {linhas.map((linha) => (
                    <div key={linha.codigo} className="relative flex h-full flex-1 items-end justify-center">
                      <div
                        className="relative w-full max-w-[3rem] rounded-t-sm"
                        style={{ height: `${(linha.qtd / topo) * 100}%`, backgroundColor: cor, minHeight: linha.qtd > 0 ? 2 : 0 }}
                      >
                        <span className="absolute bottom-full left-1/2 mb-0.5 -translate-x-1/2 text-xs font-bold tabular-nums text-slate-900">
                          {linha.qtd}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div className="mt-1 flex justify-around gap-2 px-1">
              {linhas.map((linha) => (
                <span
                  key={linha.codigo}
                  className="min-w-0 flex-1 text-center text-[10px] leading-tight text-slate-600 sm:text-[11px]"
                >
                  {linha.rotulo}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

// ---------- Tabelas ----------

const classeCelulaTitulo = "px-3 py-1.5 text-left text-xs font-semibold text-slate-700";

function TabelaCategorias({
  bloco,
  icone: Icone,
  cor,
  fundo,
}: {
  bloco: BlocoResumo;
  icone: LucideIcon;
  cor: string;
  fundo: string;
}) {
  return (
    <section aria-label={bloco.rotulo} className={`${classeCartao} overflow-hidden`}>
      <h3 className={`flex items-center gap-2 px-4 py-2.5 text-sm font-semibold text-slate-900 ${fundo}`}>
        <Icone className="h-4 w-4" style={{ color: cor }} aria-hidden="true" />
        {bloco.rotulo} ({bloco.total})
      </h3>
      <table className="w-full text-sm">
        <thead>
          <tr className="border-y border-slate-200 bg-slate-50">
            <th scope="col" className={classeCelulaTitulo}>
              Categoria
            </th>
            <th scope="col" className={`${classeCelulaTitulo} w-28 text-center`}>
              Quantidade
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {bloco.linhas.map((linha) => (
            <tr key={linha.codigo}>
              <td className="px-3 py-1.5 text-slate-700">{linha.rotulo}</td>
              <td className="px-3 py-1.5 text-center font-medium tabular-nums text-slate-900">{linha.qtd}</td>
            </tr>
          ))}
          {bloco.linhas.length === 0 && (
            <tr>
              <td colSpan={2} className="px-3 py-3 text-center text-slate-500">
                Nenhuma categoria.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </section>
  );
}

function TabelaInstrumentos({ titulo, itens }: { titulo: string; itens: { nome: string; familia: string; qtd: number; percentual: string }[] }) {
  return (
    <table className="w-full self-start text-sm">
      <thead>
        <tr className="border-y border-slate-200 bg-slate-50">
          <th scope="col" className={classeCelulaTitulo}>
            {titulo}
          </th>
          <th scope="col" className={`${classeCelulaTitulo} w-24 text-center`}>
            Quantidade
          </th>
          <th scope="col" className={`${classeCelulaTitulo} w-16 text-center`}>
            %
          </th>
        </tr>
      </thead>
      <tbody className="divide-y divide-slate-100">
        {itens.map((item) => (
          <tr key={`${item.familia}-${item.nome}`}>
            <td className="px-3 py-1.5 text-slate-700">
              <span className="flex items-center gap-2">
                <span
                  className={`h-2.5 w-2.5 shrink-0 rounded-full ${COR_FAMILIA[item.familia] ?? "bg-slate-400"}`}
                  aria-hidden="true"
                />
                {item.nome}
              </span>
            </td>
            <td className="px-3 py-1.5 text-center font-medium tabular-nums text-slate-900">{item.qtd}</td>
            <td className="px-3 py-1.5 text-center tabular-nums text-slate-600">{item.percentual}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// ---------- Painel completo ----------

export default function PainelTotais({ dados }: { dados: DadosPainelTotais }) {
  const blocos = agruparBlocos(dados.linhas);
  const [ministerio, musicos, organistas] = blocos;
  const { total: totalInstrumentos, familias, instrumentos } = montarInstrumentos(dados);
  const evento = dados.evento;
  const local = [evento.casa_oracao ?? evento.local, evento.cidade].filter(Boolean).join(" · ");
  const [coluna1, coluna2] = dividirEmDuas(instrumentos ?? []);

  return (
    <div className="space-y-4">
      {/* Título e dados do evento */}
      <section className={`${classeCartao} flex flex-wrap items-center justify-between gap-4 px-5 py-4`}>
        <div className="flex min-w-0 items-center gap-3">
          <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-700">
            <CalendarDays className="h-7 w-7" aria-hidden="true" />
          </span>
          <div className="min-w-0">
            <h2 className="text-xl font-bold text-slate-900">Painel de Totais</h2>
            <p className="text-sm text-slate-600">Resumo da presença no evento selecionado.</p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <div className="min-w-0 rounded-lg border border-brand-200 bg-brand-50 px-4 py-2">
            <p className="truncate text-sm font-bold text-brand-900">{evento.tipo}</p>
            <p className="flex flex-wrap items-center gap-x-2 text-xs uppercase tracking-wide text-slate-600">
              {local && <span>{local}</span>}
              <span className="inline-flex items-center gap-1">
                <CalendarDays className="h-3 w-3" aria-hidden="true" />
                {formatarDiaDoEvento(evento.data_evento)}
              </span>
              <span className="inline-flex items-center gap-1">
                <Clock className="h-3 w-3" aria-hidden="true" />
                {formatarHoraDoEvento(evento.data_evento)}
              </span>
            </p>
          </div>
          <BotaoImprimirPainel dados={dados} />
        </div>
      </section>

      {/* Totais (cada pessoa conta uma vez só) */}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <CartaoTotal icone={Users} titulo="Total de participantes" valor={dados.total} fundo="border-blue-200 bg-blue-50" cor={COR_MINISTERIO} />
        <CartaoTotal icone={Users} titulo="Ministério" valor={ministerio.total} fundo="border-orange-200 bg-orange-50" cor={COR_ORGANISTAS} />
        <CartaoTotal icone={Music} titulo="Músicos" valor={musicos.total} fundo="border-emerald-200 bg-emerald-50" cor={COR_MUSICOS} />
        <CartaoTotal icone={Keyboard} titulo="Organistas" valor={organistas.total} fundo="border-amber-200 bg-amber-50" cor="#b45309" />
      </div>

      {/* Gráficos */}
      <div className="grid gap-3 lg:grid-cols-3">
        <GraficoRosca blocos={blocos} />
        <GraficoBarras titulo="Músicos por categoria" icone={Music} cor="#3b82f6" linhas={musicos.linhas} />
        <GraficoBarras titulo="Organistas por categoria" icone={Keyboard} cor={COR_ORGANISTAS} linhas={organistas.linhas} />
      </div>

      {/* Tabelas por grupo */}
      <div className="grid gap-3 lg:grid-cols-3">
        <TabelaCategorias bloco={ministerio} icone={Users} cor={COR_MINISTERIO} fundo="bg-blue-50" />
        <TabelaCategorias bloco={musicos} icone={Music} cor={COR_MINISTERIO} fundo="bg-blue-50" />
        <TabelaCategorias bloco={organistas} icone={Keyboard} cor={COR_ORGANISTAS} fundo="bg-orange-50" />
      </div>

      {/* Participantes por instrumento (recorte de quem toca; não soma ao total de participantes) */}
      <section aria-label="Participantes por instrumento" className={`${classeCartao} p-4`}>
        <h3 className="flex items-center gap-2 text-sm font-semibold text-slate-900">
          <Guitar className="h-4 w-4" style={{ color: COR_MUSICOS }} aria-hidden="true" />
          Participantes por instrumento
          <span className="font-normal text-slate-500">({totalInstrumentos} tocando)</span>
        </h3>
        <div className="mt-3 grid gap-4 lg:grid-cols-3">
          <table className="w-full self-start text-sm">
            <thead>
              <tr className="border-y border-slate-200 bg-slate-50">
                <th scope="col" className={classeCelulaTitulo}>
                  Família
                </th>
                <th scope="col" className={`${classeCelulaTitulo} w-24 text-center`}>
                  Quantidade
                </th>
                <th scope="col" className={`${classeCelulaTitulo} w-16 text-center`}>
                  %
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {familias.map((familia) => (
                <tr key={familia.nome}>
                  <td className="px-3 py-2 text-slate-800">
                    <span className="flex items-center gap-2 font-medium">
                      <span
                        className={`h-3 w-3 shrink-0 rounded-full ${COR_FAMILIA[familia.nome] ?? "bg-slate-400"}`}
                        aria-hidden="true"
                      />
                      {familia.nome}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-center font-medium tabular-nums text-slate-900">{familia.qtd}</td>
                  <td className="px-3 py-2 text-center tabular-nums text-slate-600">{familia.percentual}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {instrumentos === null ? (
            <p className="text-sm text-slate-500 lg:col-span-2">
              O detalhe por instrumento aparece depois que a atualização do banco de dados (migração 0049) for aplicada.
            </p>
          ) : instrumentos.length === 0 ? (
            <p className="text-sm text-slate-500 lg:col-span-2">Nenhum instrumento registrado ainda neste evento.</p>
          ) : (
            <>
              <TabelaInstrumentos titulo="Instrumento" itens={coluna1} />
              <TabelaInstrumentos titulo="Instrumento" itens={coluna2} />
            </>
          )}
        </div>
      </section>
    </div>
  );
}
