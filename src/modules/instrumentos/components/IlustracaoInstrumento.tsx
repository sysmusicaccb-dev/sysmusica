/**
 * Sysmusica — Ilustração simples do instrumento (ícone desenhado em SVG, original do Sysmusica).
 * O desenho vem do NOME do instrumento; sem desenho próprio, usa o da família (regras em ../ilustracoes.ts).
 * A cor acompanha o texto (currentColor); o desenho é decorativo e o nome do instrumento fica ao lado.
 */
import type { ReactNode } from "react";
import { escolherDesenho, type ChaveDesenho } from "../ilustracoes";

interface IlustracaoInstrumentoProps {
  nome: string; // nome do instrumento
  familia?: string | null; // nome da família (desenho genérico quando o instrumento não tem desenho próprio)
  tamanho?: "pequeno" | "grande";
}

/** Traços de cada desenho (caixa 48 x 48). */
function tracos(chave: ChaveDesenho): ReactNode {
  switch (chave) {
    case "clarinete":
      return (
        <>
          <path d="M21.5 4h5l-1 6h-3z" />
          <path d="M22.5 10v25M25.5 10v25" />
          <path d="M22.5 35l-4 8.5h11l-4-8.5" />
          <circle cx="24" cy="16" r="1.2" fill="currentColor" /><circle cx="24" cy="22" r="1.2" fill="currentColor" /><circle cx="24" cy="28" r="1.2" fill="currentColor" />
        </>
      );
    case "clarone":
      return (
        <>
          <path d="M10 7c7-3 14-2 14 7" />
          <path d="M22.5 13v22M25.5 13v22" />
          <path d="M22.5 35c0 6 4 8 9 8 5 0 7-3 7-8l3-5" />
          <path d="M25.5 35c0 2 2 3 4 3s3-1 3-3" />
          <circle cx="24" cy="19" r="1.2" fill="currentColor" /><circle cx="24" cy="25" r="1.2" fill="currentColor" /><circle cx="24" cy="31" r="1.2" fill="currentColor" />
        </>
      );
    case "flauta":
      return (
        <>
          <g transform="rotate(-28 24 24)">
          <rect x="3" y="21" width="42" height="6" rx="3" />
          <ellipse cx="10" cy="24" rx="1.6" ry="1.2" />
          <circle cx="19" cy="24" r="1.2" fill="currentColor" /><circle cx="25" cy="24" r="1.2" fill="currentColor" /><circle cx="31" cy="24" r="1.2" fill="currentColor" /><circle cx="37" cy="24" r="1.2" fill="currentColor" />
          </g>
        </>
      );
    case "oboe":
      return (
        <>
          <path d="M23 3v6M25 3v6" />
          <path d="M22.5 9l-.5 26M25.5 9l.5 26" />
          <path d="M22 35l-2.5 6h9l-2.5-6" />
          <circle cx="24" cy="16" r="1.1" fill="currentColor" /><circle cx="24" cy="22" r="1.1" fill="currentColor" /><circle cx="24" cy="28" r="1.1" fill="currentColor" />
        </>
      );
    case "sax":
      return (
        <>
          <path d="M10 6c6-2 12 0 12 8" />
          <path d="M21 14v18c0 8 5 11 11 11 6 0 8-4 8-9l2-6" />
          <path d="M27 14v18c0 2 1 3 3 3s3-1 3-3l-1-3" />
          <path d="M36 28h8" />
          <circle cx="24" cy="19" r="1.2" fill="currentColor" /><circle cx="24" cy="25" r="1.2" fill="currentColor" /><circle cx="24" cy="31" r="1.2" fill="currentColor" />
        </>
      );
    case "sax_reto":
      return (
        <>
          <path d="M21 4h4l2 5h-6z" />
          <path d="M22 9v28M26 9v28" />
          <path d="M22 37c-1 4-1 6 1 6h5" />
          <path d="M26 37l5 2 3-3" />
          <circle cx="24" cy="16" r="1.2" fill="currentColor" /><circle cx="24" cy="23" r="1.2" fill="currentColor" /><circle cx="24" cy="30" r="1.2" fill="currentColor" />
        </>
      );
    case "sax_curvo":
      return (
        <>
          <path d="M21 4h4l2 5h-6z" />
          <path d="M22 9v26M26 9v26" />
          <path d="M22 35c0 6 3 8 8 8 5 0 8-3 8-8" />
          <path d="M26 35c0 2 2 3 4 3" />
          <circle cx="24" cy="16" r="1.2" fill="currentColor" /><circle cx="24" cy="23" r="1.2" fill="currentColor" /><circle cx="24" cy="30" r="1.2" fill="currentColor" />
        </>
      );
    case "trompete":
      return (
        <>
          <path d="M30 19l14-8v26l-14-8" />
          <path d="M8 19h22M8 29h22" />
          <path d="M8 19c-6 0-6 10 0 10" />
          <path d="M15 19v-6M21 19v-6M27 19v-6" />
          <path d="M13 13h4M19 13h4M25 13h4" />
        </>
      );
    case "flugelhorn":
      return (
        <>
          <path d="M28 18l16-10v32l-16-10" />
          <path d="M8 18h20M8 30h20" />
          <path d="M8 18c-6 0-6 12 0 12" />
          <path d="M14 18v-6M20 18v-6M26 18v-5" />
          <path d="M12 12h4M18 12h4M24 12h4" />
        </>
      );
    case "bombardino":
      return (
        <>
          <path d="M27 4h16l-4 18" />
          <path d="M27 4l4 18" />
          <circle cx="22" cy="32" r="12" />
          <circle cx="22" cy="32" r="6" />
          <path d="M31 24l8-2" />
          <path d="M10 28H4M10 36H5" />
        </>
      );
    case "trombone":
      return (
        <>
          <path d="M6 18h28M6 25h28" />
          <path d="M6 18v7" />
          <path d="M34 18l10-8v30l-10-8z" />
          <path d="M6 32h30" />
          <path d="M6 32v6h30v-6" />
        </>
      );
    case "tuba":
      return (
        <>
          <path d="M12 4h24l-4 14H16z" />
          <path d="M16 18c-8 2-10 10-10 16 0 7 6 10 14 10 8 0 14-4 14-12 0-6-4-12-12-14" />
          <path d="M20 34c0-4 2-6 6-6" />
          <path d="M32 20l8 4" />
        </>
      );
    case "acordeon":
      return (
        <>
          <rect x="3" y="11" width="9" height="26" rx="2" />
          <rect x="36" y="11" width="9" height="26" rx="2" />
          <path d="M12 13l4 22 4-22 4 22 4-22 4 22 4-22" />
          <circle cx="7.5" cy="19" r="1.3" fill="currentColor" /><circle cx="7.5" cy="25" r="1.3" fill="currentColor" /><circle cx="7.5" cy="31" r="1.3" fill="currentColor" />
          <path d="M40.5 17v14M40.5 17h0" />
        </>
      );
    case "orgao":
      return (
        <>
          <rect x="3" y="12" width="42" height="26" rx="3" />
          <path d="M3 24h42" />
          <path d="M10 24v14M17 24v14M24 24v14M31 24v14M38 24v14" />
          <rect x="8" y="24" width="4" height="8" fill="currentColor" /><rect x="15" y="24" width="4" height="8" fill="currentColor" /><rect x="29" y="24" width="4" height="8" fill="currentColor" /><rect x="36" y="24" width="4" height="8" fill="currentColor" />
          <circle cx="9" cy="18" r="1.3" fill="currentColor" /><circle cx="15" cy="18" r="1.3" fill="currentColor" /><path d="M24 18h16" />
        </>
      );
    case "violino":
      return (
        <>
          <path d="M24 14V4" />
          <circle cx="24" cy="3.5" r="1.6" />
          <path d="M24 14c-4 0-6 2-6 5 0 2 1 3 2 4-3 1-5 3-5 7 0 6 4 10 9 10s9-4 9-10c0-4-2-6-5-7 1-1 2-2 2-4 0-3-2-5-6-5z" />
          <path d="M21 28c-1 3-1 5 0 7M27 28c1 3 1 5 0 7" />
          <path d="M24 22v17M20 40h8" />
        </>
      );
    case "nota":
      return (
        <>
          <path d="M18 36V10l18-4v26" />
          <circle cx="13" cy="36" r="5" />
          <circle cx="31" cy="32" r="5" />
        </>
      );
  }
}

export default function IlustracaoInstrumento({ nome, familia, tamanho = "pequeno" }: IlustracaoInstrumentoProps) {
  const chave = escolherDesenho(nome, familia);
  const medidas = tamanho === "grande" ? "h-14 w-14 p-2" : "h-8 w-8 p-1";

  return (
    <span
      aria-hidden="true"
      className={"inline-flex shrink-0 items-center justify-center rounded-lg bg-indigo-50 text-indigo-700 " + medidas}
    >
      <svg
        viewBox="0 0 48 48"
        fill="none"
        stroke="currentColor"
        strokeWidth={2.2}
        strokeLinecap="round"
        strokeLinejoin="round"
        className="h-full w-full"
      >
        {tracos(chave)}
      </svg>
    </span>
  );
}
