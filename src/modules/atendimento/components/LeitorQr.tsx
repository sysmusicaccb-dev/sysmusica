"use client";

/**
 * SysMúsica — Leitor de QR Code pela câmera.
 * Abre a câmera sozinho (traseira, quando houver) e fica aguardando. Enquanto "ativo" for falso
 * (conferência aberta ou consulta em andamento), as leituras são ignoradas. A mesma leitura repetida
 * em menos de 3 segundos também é ignorada. Sem câmera, sem permissão ou sem https, mostra o motivo.
 * A biblioteca só é carregada no navegador (import dinâmico).
 */
import { useEffect, useRef, useState } from "react";
import type QrScanner from "qr-scanner";
import { mensagemCamera } from "../regras";

interface LeitorQrProps {
  ativo: boolean;
  onLeitura: (texto: string) => void;
}

type Situacao = "iniciando" | "lendo" | "erro";

const classeBotao =
  "rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50";

export default function LeitorQr({ ativo, onLeitura }: LeitorQrProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const leitorRef = useRef<QrScanner | null>(null);
  // Referências sempre atualizadas: a câmera não reinicia quando a tela muda
  const ativoRef = useRef(ativo);
  const aoLerRef = useRef(onLeitura);
  const ultimaLeituraRef = useRef<{ texto: string; quando: number } | null>(null);

  const [situacao, setSituacao] = useState<Situacao>("iniciando");
  const [mensagem, setMensagem] = useState<string | null>(null);
  const [tentativa, setTentativa] = useState(0);
  const [traseira, setTraseira] = useState(true);

  useEffect(() => {
    ativoRef.current = ativo;
    aoLerRef.current = onLeitura;
  }, [ativo, onLeitura]);

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    let cancelado = false;
    let leitor: QrScanner | null = null;

    async function iniciar() {
      try {
        if (!window.isSecureContext) throw new Error("INSEGURO");
        const { default: QrScannerClasse } = await import("qr-scanner");
        if (cancelado || !videoRef.current) return;
        if (!(await QrScannerClasse.hasCamera())) throw new Error("SEM_CAMERA");

        leitor = new QrScannerClasse(
          videoRef.current,
          (resultado) => {
            const texto = resultado.data.trim();
            if (!ativoRef.current || texto === "") return;

            const agora = Date.now();
            const ultima = ultimaLeituraRef.current;
            if (ultima && ultima.texto === texto && agora - ultima.quando < 3000) return;

            ultimaLeituraRef.current = { texto, quando: agora };
            aoLerRef.current(texto);
          },
          {
            preferredCamera: "environment",
            highlightScanRegion: true,
            highlightCodeOutline: true,
            maxScansPerSecond: 6,
            returnDetailedScanResult: true,
          }
        );
        leitorRef.current = leitor;
        await leitor.start();
        if (cancelado) return; // a limpeza abaixo encerra a câmera
        setSituacao("lendo");
        setMensagem(null);
      } catch (e) {
        if (cancelado) return;
        setSituacao("erro");
        setMensagem(mensagemCamera(e));
      }
    }

    void iniciar();
    return () => {
      cancelado = true;
      leitorRef.current = null;
      leitor?.destroy();
    };
  }, [tentativa]);
  /* eslint-enable react-hooks/set-state-in-effect */

  function reiniciar() {
    setSituacao("iniciando");
    setMensagem(null);
    setTentativa((anterior) => anterior + 1);
  }

  async function trocarCamera() {
    const proxima = !traseira;
    try {
      await leitorRef.current?.setCamera(proxima ? "environment" : "user");
      setTraseira(proxima);
    } catch (e) {
      setMensagem(mensagemCamera(e));
    }
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="relative mx-auto aspect-square w-full max-w-md bg-slate-900 sm:aspect-video sm:max-w-none">
        <video ref={videoRef} muted playsInline className="h-full w-full object-cover" />
        {situacao !== "lendo" && (
          <div className="absolute inset-0 flex items-center justify-center p-6 text-center text-sm text-white">
            {situacao === "iniciando" ? "Iniciando a câmera..." : mensagem}
          </div>
        )}
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2 p-4">
        <p className="text-sm text-slate-600" aria-live="polite">
          {situacao === "lendo"
            ? ativo
              ? "Pronto: aponte a câmera para o QR Code do membro."
              : "Aguardando a conferência..."
            : "Câmera indisponível no momento."}
        </p>
        <div className="flex gap-2">
          {situacao === "erro" && (
            <button type="button" onClick={reiniciar} className={classeBotao}>
              Tentar novamente
            </button>
          )}
          {situacao === "lendo" && (
            <button type="button" onClick={() => void trocarCamera()} className={classeBotao}>
              Trocar câmera
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
