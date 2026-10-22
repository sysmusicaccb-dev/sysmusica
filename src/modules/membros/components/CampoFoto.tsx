"use client";

/**
 * Sysmusica — Campo de fotografia: "Tirar foto" e "Escolher da galeria", com pré-visualização.
 * No celular, "Tirar foto" abre a câmera do aparelho; no computador abre o seletor de arquivos.
 * A imagem é reduzida e convertida para JPEG no navegador (leve e rápida de enviar). O arquivo só é
 * enviado quando o formulário que usa este campo salvar. Sem foto nova, mostra a foto atual (se houver).
 */
import { useEffect, useRef, useState, type ChangeEvent } from "react";
import { Camera, ImagePlus, Trash2 } from "lucide-react";
import { prepararFoto } from "../fotoImagem";
import FotoMembro from "./FotoMembro";

interface CampoFotoProps {
  nome: string; // para o texto alternativo da imagem
  fotoAtualCaminho?: string | null; // foto já cadastrada (edição)
  obrigatoria?: boolean;
  onChange: (foto: Blob | null) => void; // a foto nova já preparada, ou nulo ao remover a escolha
  disabled?: boolean;
}

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function CampoFoto({
  nome,
  fotoAtualCaminho = null,
  obrigatoria = false,
  onChange,
  disabled = false,
}: CampoFotoProps) {
  const cameraRef = useRef<HTMLInputElement>(null);
  const galeriaRef = useRef<HTMLInputElement>(null);
  const [previa, setPrevia] = useState<string | null>(null); // endereço temporário da foto nova
  const [processando, setProcessando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Libera o endereço temporário da pré-visualização quando ela troca ou o campo sai da tela
  useEffect(() => {
    return () => {
      if (previa) URL.revokeObjectURL(previa);
    };
  }, [previa]);

  async function aoEscolher(evento: ChangeEvent<HTMLInputElement>) {
    const arquivo = evento.target.files?.[0];
    evento.target.value = ""; // permite escolher o mesmo arquivo de novo
    if (!arquivo) return;

    setErro(null);
    setProcessando(true);
    try {
      const imagem = await prepararFoto(arquivo);
      setPrevia(URL.createObjectURL(imagem));
      onChange(imagem);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível preparar a imagem.");
    } finally {
      setProcessando(false);
    }
  }

  function removerEscolha() {
    setPrevia(null);
    onChange(null);
  }

  const bloqueado = disabled || processando;

  return (
    <div className="space-y-3">
      {/* Câmera (celular) e galeria: seletores escondidos, acionados pelos botões abaixo */}
      <input
        ref={cameraRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => void aoEscolher(e)}
      />
      <input
        ref={galeriaRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => void aoEscolher(e)}
      />

      <div className="flex items-start gap-4">
        {previa ? (
          <div
            role="img"
            aria-label={`Nova fotografia de ${nome}`}
            style={{ backgroundImage: `url(${previa})` }}
            className="h-44 w-36 shrink-0 rounded-xl bg-slate-100 bg-cover bg-center"
          />
        ) : (
          <FotoMembro caminho={fotoAtualCaminho} nome={nome} tamanho="grande" />
        )}

        <div className="flex flex-col gap-2">
          <button type="button" className={classeBotao} onClick={() => cameraRef.current?.click()} disabled={bloqueado}>
            <Camera className="h-4 w-4" aria-hidden="true" />
            Tirar foto
          </button>
          <button type="button" className={classeBotao} onClick={() => galeriaRef.current?.click()} disabled={bloqueado}>
            <ImagePlus className="h-4 w-4" aria-hidden="true" />
            Escolher da galeria
          </button>
          {previa && (
            <button type="button" className={classeBotao} onClick={removerEscolha} disabled={bloqueado}>
              <Trash2 className="h-4 w-4" aria-hidden="true" />
              Remover a nova foto
            </button>
          )}
        </div>
      </div>

      {processando && <p className="text-xs text-slate-500">Preparando a imagem...</p>}
      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
      <p className="text-xs text-slate-500">
        {obrigatoria ? "A fotografia é obrigatória: ela identifica a pessoa na portaria. " : ""}
        Foto de rosto, de frente e com boa luz. A imagem é reduzida antes de ser enviada.
      </p>
    </div>
  );
}
