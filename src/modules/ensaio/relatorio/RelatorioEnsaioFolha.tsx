/**
 * Sysmusica — Folha do Relatório do Ensaio (A4 paisagem, 1280 x 905 px).
 * Todos os estilos são INLINE (sem Tailwind): assim a mesma folha aparece igual na tela e na janela de impressão,
 * que recebe uma cópia do HTML pronto. Os números e nomes vêm do modelo (modelo.ts), que vem do banco.
 */
import type { CSSProperties, ReactNode } from "react";
import { tracos } from "@/modules/instrumentos/components/IlustracaoInstrumento";
import { escalaDoGrafico, fatiasDaRosca } from "@/modules/painel/detalhe";
import type { BlocoFolha, ModeloRelatorio } from "./modelo";

export const LARGURA_FOLHA = 1280;
export const ALTURA_FOLHA = 905;

const AZUL = "#0b2a5b"; // azul-marinho
const AZUL_CLARO = "#e8f0fb";
const AZUL_MEDIO = "#2563eb";
const CINZA = "#475569";
const FONTE = "Arial, Helvetica, sans-serif";

const cartao: CSSProperties = {
  flex: 1,
  background: "#fff",
  border: "1.5px solid #c7d6ee",
  borderRadius: 12,
  overflow: "hidden",
  display: "flex",
  flexDirection: "column",
};
const cabecalhoCartao: CSSProperties = {
  background: AZUL,
  color: "#fff",
  fontSize: 13,
  fontWeight: 700,
  letterSpacing: 0.6,
  textTransform: "uppercase",
  padding: "6px 12px",
};

function Cartao({ titulo, children, estilo }: { titulo: string; children: ReactNode; estilo?: CSSProperties }) {
  return (
    <section style={{ ...cartao, ...estilo }}>
      <div style={cabecalhoCartao}>{titulo}</div>
      <div style={{ padding: "8px 12px", fontSize: 15, color: "#0f172a", flex: 1, display: "flex", flexDirection: "column", justifyContent: "center" }}>{children}</div>
    </section>
  );
}

function Tabela({ bloco, destaque }: { bloco: BlocoFolha; destaque?: boolean }) {
  return (
    <section style={{ ...cartao, alignSelf: "start" }}>
      <div style={cabecalhoCartao}>{bloco.titulo}</div>
      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
        <tbody>
          {bloco.linhas.map((l, i) => (
            <tr key={l.rotulo} style={{ background: i % 2 ? AZUL_CLARO : "#fff" }}>
              <td style={{ padding: "4px 12px" }}>{l.rotulo}</td>
              <td style={{ padding: "4px 12px", textAlign: "right", fontWeight: 700 }}>{l.qtd}</td>
            </tr>
          ))}
          <tr style={{ color: "#fff", fontWeight: 700 }}>
            <td style={{ padding: "4px 12px", background: destaque ? AZUL : AZUL_MEDIO }}>TOTAL</td>
            <td style={{ padding: "4px 12px", textAlign: "right", background: destaque ? AZUL : AZUL_MEDIO }}>{bloco.total}</td>
          </tr>
        </tbody>
      </table>
    </section>
  );
}

/** Rosca das famílias (Cordas, Madeiras, Metais...). */
function Rosca({ m }: { m: ModeloRelatorio }) {
  const R = 60;
  const C = 2 * Math.PI * R;
  const fatias = fatiasDaRosca(
    m.familias.map((f) => ({ rotulo: f.nome, qtd: f.qtd })),
    C
  );
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
      <svg width={150} height={150} viewBox="0 0 150 150" role="img" aria-label="Instrumentos por família">
        <circle cx={75} cy={75} r={R} fill="none" stroke="#e2e8f0" strokeWidth={26} />
        {fatias.map((f, i) =>
          f.comprimento > 0 ? (
            <circle
              key={f.rotulo}
              cx={75}
              cy={75}
              r={R}
              fill="none"
              stroke={m.familias[i].cor}
              strokeWidth={26}
              strokeDasharray={`${f.comprimento} ${C - f.comprimento}`}
              strokeDashoffset={-f.deslocamento}
              transform="rotate(-90 75 75)"
            />
          ) : null
        )}
        <text x={75} y={72} textAnchor="middle" fontSize={26} fontWeight={700} fill={AZUL} fontFamily={FONTE}>
          {m.totalInstrumentos}
        </text>
        <text x={75} y={90} textAnchor="middle" fontSize={11} fill={CINZA} fontFamily={FONTE}>
          tocando
        </text>
      </svg>
      <ul style={{ listStyle: "none", margin: 0, padding: 0, fontSize: 14 }}>
        {m.familias.map((f) => (
          <li key={f.nome} style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 5 }}>
            <span style={{ width: 12, height: 12, borderRadius: 3, background: f.cor, display: "inline-block" }} />
            <span style={{ minWidth: 70 }}>{f.nome}</span>
            <strong>{f.qtd}</strong>
            <span style={{ color: CINZA }}>({f.percentual})</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Barras por instrumento, com o ícone embaixo de cada barra. */
function Barras({ m }: { m: ModeloRelatorio }) {
  const itens = m.instrumentos;
  if (itens.length === 0) return <p style={{ color: CINZA, fontSize: 14 }}>Nenhum instrumento registrado.</p>;
  const { topo, marcas } = escalaDoGrafico(itens.map((i) => i.qtd));
  const LARG = 700;
  const ALT = 215;
  const ESQ = 28;
  const BASE = 150; // linha do zero
  const ALTURA_UTIL = 125;
  const passo = (LARG - ESQ) / itens.length;
  const larguraBarra = Math.min(34, passo * 0.6);
  const cor = (familia: string) => m.familias.find((f) => f.nome === familia)?.cor ?? AZUL_MEDIO;
  return (
    <svg width="100%" viewBox={`0 0 ${LARG} ${ALT}`} role="img" aria-label="Instrumentos" fontFamily={FONTE}>
      {marcas.map((v) => {
        const y = BASE - (v / topo) * ALTURA_UTIL;
        return (
          <g key={v}>
            <line x1={ESQ} x2={LARG} y1={y} y2={y} stroke="#e2e8f0" strokeWidth={1} />
            <text x={ESQ - 5} y={y + 4} textAnchor="end" fontSize={10} fill={CINZA}>
              {v}
            </text>
          </g>
        );
      })}
      {itens.map((it, i) => {
        const cx = ESQ + passo * i + passo / 2;
        const h = (it.qtd / topo) * ALTURA_UTIL;
        return (
          <g key={it.nome}>
            <rect x={cx - larguraBarra / 2} y={BASE - h} width={larguraBarra} height={h} rx={3} fill={cor(it.familia)} />
            <text x={cx} y={BASE - h - 4} textAnchor="middle" fontSize={11} fontWeight={700} fill="#0f172a">
              {it.qtd}
            </text>
            <svg x={cx - 12} y={BASE + 4} width={24} height={24} viewBox="0 0 48 48" fill="none" stroke={cor(it.familia)} strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" style={{ color: cor(it.familia) }}>
              {tracos(it.desenho)}
            </svg>
            <text x={cx} y={BASE + 42} textAnchor="middle" fontSize={passo < 52 ? 8.5 : 10} fill="#0f172a">
              {it.nome.length > 11 ? it.nome.slice(0, 10) + "." : it.nome}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

function Totais({ m }: { m: ModeloRelatorio }) {
  const caixa = (rotulo: string, valor: number, forte: boolean) => (
    <div
      style={{
        flex: 1,
        textAlign: "center",
        borderRadius: 12,
        padding: "10px 6px",
        background: forte ? AZUL : AZUL_CLARO,
        color: forte ? "#fff" : AZUL,
        border: "1.5px solid #c7d6ee",
      }}
    >
      <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.6, textTransform: "uppercase" }}>{rotulo}</div>
      <div style={{ fontSize: 34, fontWeight: 800, lineHeight: 1.1 }}>{valor}</div>
    </div>
  );
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {caixa("Ministério", m.ministerio.total, false)}
      {caixa("Orquestra", m.orquestra, false)}
      {caixa("Total geral", m.totalGeral, true)}
    </div>
  );
}

export default function RelatorioEnsaioFolha({ m }: { m: ModeloRelatorio }) {
  const topo: ReactNode[] = [];
  if (m.atendimento) topo.push(<Cartao key="a" titulo={m.atendimento.titulo}>{m.atendimento.texto}</Cartao>);
  if (m.regencia)
    topo.push(
      <Cartao key="r" titulo={m.regencia.titulo}>
        {m.regencia.nomes.length > 0 ? m.regencia.nomes.map((n) => <div key={n}>{n}</div>) : "—"}
      </Cartao>
    );
  if (m.palavra !== null)
    topo.push(
      <Cartao key="p" titulo="Palavra" estilo={{ flex: 2 }}>
        <span style={{ fontStyle: "italic" }}>{m.palavra}</span>
      </Cartao>
    );
  if (m.hinos)
    topo.push(
      <Cartao key="h" titulo={`Hinos (${m.hinos.total})`} estilo={{ flex: 2 }}>
        {m.hinos.abertura && (
          <div style={{ marginBottom: 4 }}>
            <strong>Abertura:</strong> {m.hinos.abertura}
          </div>
        )}
        <div style={{ lineHeight: 1.5 }}>{m.hinos.numeros.length > 0 ? m.hinos.numeros.join(" · ") : "—"}</div>
      </Cartao>
    );
  if (m.extras.length > 0)
    topo.push(
      <Cartao key="x" titulo="Informações adicionais" estilo={{ flex: 2 }}>
        {m.extras.map((x) => (
          <div key={x.rotulo}>
            <strong>{x.rotulo}:</strong> {x.valor}
          </div>
        ))}
      </Cartao>
    );

  return (
    <div
      data-folha-relatorio="1"
      style={{
        width: LARGURA_FOLHA,
        height: ALTURA_FOLHA,
        display: "flex",
        background: "#f4f8ff",
        fontFamily: FONTE,
        color: "#0f172a",
        position: "relative",
        overflow: "hidden",
        boxSizing: "border-box",
      }}
    >
      {/* Faixa azul da esquerda: nome do sistema, notas e silhueta simples de prédio */}
      <aside style={{ width: 130, background: AZUL, color: "#fff", display: "flex", flexDirection: "column", alignItems: "center", padding: "22px 0", boxSizing: "border-box" }}>
        <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: 0.3, whiteSpace: "nowrap" }}>{m.marca}</div>
        <div style={{ fontSize: 34, opacity: 0.25, marginTop: 36 }}>♫</div>
        <div style={{ fontSize: 26, opacity: 0.18, marginTop: 10 }}>♪</div>
        <svg width={90} height={110} viewBox="0 0 90 110" style={{ marginTop: "auto", opacity: 0.3 }} aria-hidden="true">
          <path d="M10 108V52l35-34 35 34v56z M38 108V80h14v28 M45 6v12 M39 12h12" fill="none" stroke="#fff" strokeWidth={3} strokeLinejoin="round" />
        </svg>
      </aside>

      <div style={{ flex: 1, padding: "20px 28px 14px", display: "flex", flexDirection: "column", gap: 12, boxSizing: "border-box" }}>
        {/* Cabeçalho */}
        <header style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", gap: 6, borderBottom: `4px solid ${AZUL_MEDIO}`, paddingBottom: 10 }}>
          <div style={{ fontSize: m.titulo.length > 26 ? 34 : 40, fontWeight: 800, color: AZUL, letterSpacing: 1, lineHeight: 1.05 }}>{m.titulo}</div>
          <div style={{ fontSize: 20, color: AZUL_MEDIO, fontWeight: 700 }}>{m.subtitulo}</div>
          <div style={{ display: "flex", gap: 8, marginTop: 2 }}>
            {[m.dia, m.diaSemana, m.hora].map((t) => (
              <span key={t} style={{ background: AZUL, color: "#fff", borderRadius: 999, padding: "5px 18px", fontSize: 16, fontWeight: 700, whiteSpace: "nowrap" }}>
                {t}
              </span>
            ))}
          </div>
        </header>

        {/* Dados do ensaio (somente o que o perfil do evento usa) */}
        {topo.length > 0 && (
          <div style={{ display: "flex", gap: 10 }}>
            {topo}
          </div>
        )}

        {/* Gráficos */}
        <div style={{ display: "grid", gridTemplateColumns: "360px 1fr", gap: 10, flex: 1, minHeight: 0 }}>
          <Cartao titulo="Instrumentos por família">
            <Rosca m={m} />
          </Cartao>
          <Cartao titulo="Instrumentos">
            <Barras m={m} />
          </Cartao>
        </div>

        {/* Tabelas e totais */}
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr", gap: 10 }}>
          <Tabela bloco={m.ministerio} />
          <Tabela bloco={m.musicos} />
          <Tabela bloco={m.organistas} />
          <div style={{ display: "flex", flexDirection: "column", justifyContent: "center", gap: 10 }}>
            <Totais m={m} />
          </div>
        </div>

        <footer style={{ display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 12, color: CINZA }}>
          <span>
            <strong style={{ color: AZUL }}>Tudo seja feito com decência e ordem.</strong> · 1 CORÍNTIOS 14:40
          </span>
          <span>
            Emitido por {m.emitidoPor} em {m.geradoEm}
          </span>
        </footer>
      </div>
    </div>
  );
}
