"use client";

/**
 * Sysmusica — Ferramenta "Logo do sistema" (dentro de Configurações). Só o administrador Master a vê.
 * Mostra a logo atual, as regras da imagem (tipo, medidas e tamanho), deixa escolher um arquivo, mostra as
 * medidas dele antes de salvar e permite voltar para a clave de sol padrão.
 */
import { useEffect, useRef, useState, type ChangeEvent } from "react";
import { ImageUp, RotateCcw } from "lucide-react";
import LogoMarca from "@/components/ui/LogoMarca";
import { useRotulosMenu } from "@/modules/menu/useRotulosMenu";
import {
  ACEITA_LOGO,
  LOGO_MAXIMO_BYTES,
  LOGO_MAXIMO_PX,
  LOGO_MINIMO_PX,
  LOGO_RECOMENDADO_PX,
  TIPOS_DE_LOGO,
  avisoDeProporcao,
  formatarTamanho,
  rotuloDoTipo,
  validarLogo,
} from "../regras";
import { enviarLogo, restaurarLogoPadrao } from "../services/marca";
import { carregarMarca, useMarca } from "../useMarca";

interface Escolha {
  arquivo: File;
  largura: number;
  altura: number;
  previa: string; // endereço temporário só para mostrar a imagem antes de salvar
}

/** Lê as medidas da imagem no próprio navegador. */
function lerMedidas(arquivo: File): Promise<{ largura: number; altura: number; previa: string }> {
  return new Promise((resolver, rejeitar) => {
    const previa = URL.createObjectURL(arquivo);
    const imagem = new window.Image();
    imagem.onload = () => {
      // SVG sem medidas próprias: o navegador pode devolver 0; como ele escala sem perder qualidade, vale a recomendada
      const svgSemMedida = arquivo.type === "image/svg+xml" && (!imagem.naturalWidth || !imagem.naturalHeight);
      resolver({
        largura: svgSemMedida ? LOGO_RECOMENDADO_PX : imagem.naturalWidth,
        altura: svgSemMedida ? LOGO_RECOMENDADO_PX : imagem.naturalHeight,
        previa,
      });
    };
    imagem.onerror = () => {
      URL.revokeObjectURL(previa);
      rejeitar(new Error("Não foi possível abrir esta imagem. Escolha outro arquivo."));
    };
    imagem.src = previa;
  });
}

export default function LogoDoSistema() {
  const { master } = useRotulosMenu();
  const { marca } = useMarca();
  const campoArquivo = useRef<HTMLInputElement>(null);
  const [escolha, setEscolha] = useState<Escolha | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState(false);

  // Libera o endereço temporário da prévia quando a escolha muda ou a tela fecha
  const previaAtual = escolha?.previa;
  useEffect(() => {
    return () => {
      if (previaAtual) URL.revokeObjectURL(previaAtual);
    };
  }, [previaAtual]);

  if (!master) return null;

  const problema = escolha
    ? validarLogo({ tipo: escolha.arquivo.type, bytes: escolha.arquivo.size, largura: escolha.largura, altura: escolha.altura })
    : null;
  const proporcao = escolha && !problema ? avisoDeProporcao(escolha.largura, escolha.altura) : null;

  async function aoEscolher(evento: ChangeEvent<HTMLInputElement>) {
    const arquivo = evento.target.files?.[0];
    evento.target.value = ""; // permite escolher o mesmo arquivo de novo depois
    if (!arquivo) return;
    setErro(null);
    setAviso(null);
    try {
      const medidas = await lerMedidas(arquivo);
      setEscolha({ arquivo, ...medidas });
    } catch (e) {
      setEscolha(null);
      setErro(e instanceof Error ? e.message : "Não foi possível abrir esta imagem.");
    }
  }

  async function salvar() {
    if (!escolha || problema) return;
    setOcupado(true);
    setErro(null);
    try {
      await enviarLogo(escolha.arquivo, escolha.largura, escolha.altura);
      await carregarMarca(true); // topo, menu e tela de entrada passam a mostrar a nova logo
      setEscolha(null);
      setAviso("Logo trocada. Ela já vale para todos os usuários.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível trocar a logo.");
    } finally {
      setOcupado(false);
    }
  }

  async function restaurar() {
    setOcupado(true);
    setErro(null);
    try {
      await restaurarLogoPadrao();
      await carregarMarca(true);
      setEscolha(null);
      setAviso("Voltou para a clave de sol padrão.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível restaurar a logo padrão.");
    } finally {
      setOcupado(false);
    }
  }

  const tiposTexto = TIPOS_DE_LOGO.map((tipo) => tipo.rotulo).join(", ");

  return (
    <section className="space-y-3 border-t border-slate-200 pt-5" aria-labelledby="titulo-logo-sistema">
      <h3 id="titulo-logo-sistema" className="text-sm font-medium text-slate-700">
        Logo do sistema
      </h3>

      {/* Logo que está valendo agora */}
      <div className="flex items-center gap-4">
        <div className="rounded-xl bg-[#0b3a6e] p-2">
          <LogoMarca altura={56} />
        </div>
        <div className="text-xs text-slate-600">
          {marca ? (
            <>
              <p className="font-medium text-slate-800">Logo personalizada</p>
              <p>
                {rotuloDoTipo(marca.tipo)} · {marca.largura} x {marca.altura} pixels · {formatarTamanho(marca.tamanho_bytes)}
              </p>
            </>
          ) : (
            <p className="font-medium text-slate-800">Clave de sol (padrão do sistema)</p>
          )}
          <p className="mt-1">Aparece no topo, no menu e na tela de entrada, para todos os usuários.</p>
        </div>
      </div>

      {/* Regras da imagem */}
      <ul className="list-disc space-y-0.5 pl-5 text-xs text-slate-600">
        <li>
          Tipos aceitos: <strong>{tiposTexto}</strong>.
        </li>
        <li>
          Medidas: de <strong>{LOGO_MINIMO_PX} x {LOGO_MINIMO_PX}</strong> até{" "}
          <strong>{LOGO_MAXIMO_PX} x {LOGO_MAXIMO_PX}</strong> pixels. Ideal: quadrada, de{" "}
          <strong>{LOGO_RECOMENDADO_PX} x {LOGO_RECOMENDADO_PX}</strong>.
        </li>
        <li>
          Tamanho do arquivo: até <strong>{formatarTamanho(LOGO_MAXIMO_BYTES)}</strong>.
        </li>
        <li>PNG ou SVG com fundo transparente ficam melhores. A imagem aparece sobre uma placa branca.</li>
      </ul>

      <input ref={campoArquivo} type="file" accept={ACEITA_LOGO} onChange={(e) => void aoEscolher(e)} className="sr-only" tabIndex={-1} />

      {/* Imagem escolhida: mostra o que o navegador leu antes de salvar */}
      {escolha && (
        <div className="rounded-xl border border-slate-200 bg-slate-50 p-3">
          <div className="flex items-center gap-3">
            {/* eslint-disable-next-line @next/next/no-img-element -- prévia local (endereço temporário do navegador) */}
            <img src={escolha.previa} alt="Prévia da nova logo" className="h-14 w-14 rounded-lg bg-white object-contain p-1 ring-1 ring-slate-200" />
            <dl className="min-w-0 text-xs text-slate-600">
              <dt className="sr-only">Arquivo</dt>
              <dd className="truncate font-medium text-slate-800">{escolha.arquivo.name}</dd>
              <dt className="sr-only">Detalhes</dt>
              <dd>
                {rotuloDoTipo(escolha.arquivo.type)} · {escolha.largura} x {escolha.altura} pixels ·{" "}
                {formatarTamanho(escolha.arquivo.size)}
              </dd>
            </dl>
          </div>
          {problema && (
            <p role="alert" className="mt-2 rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">
              {problema}
            </p>
          )}
          {proporcao && <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">{proporcao}</p>}
        </div>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">
          {erro}
        </p>
      )}
      {aviso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-xs text-emerald-800">
          {aviso}
        </p>
      )}

      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          disabled={ocupado}
          onClick={() => campoArquivo.current?.click()}
          className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 disabled:opacity-60"
        >
          <ImageUp className="h-4 w-4" aria-hidden="true" />
          Escolher imagem
        </button>
        {escolha && (
          <button
            type="button"
            disabled={ocupado || problema !== null}
            onClick={() => void salvar()}
            className="inline-flex items-center rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand-500 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {ocupado ? "Salvando..." : "Usar esta logo"}
          </button>
        )}
        {marca && (
          <button
            type="button"
            disabled={ocupado}
            onClick={() => void restaurar()}
            className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 disabled:opacity-60"
          >
            <RotateCcw className="h-4 w-4" aria-hidden="true" />
            Voltar para a clave de sol
          </button>
        )}
      </div>
    </section>
  );
}
