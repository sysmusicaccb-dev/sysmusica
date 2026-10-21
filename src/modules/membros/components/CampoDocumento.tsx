"use client";

/**
 * SysMúsica — Campo para anexar UM lado do documento de identificação (frente ou verso).
 * "Tirar foto" abre a câmera no celular; "Escolher da galeria" abre o seletor de arquivos. A imagem é reduzida
 * no navegador e só é enviada quando o formulário salva. Se já existe um documento anexado, o campo avisa;
 * ver o arquivo só é possível para quem tem a permissão membros.cpf (o armazenamento também confere).
 */
import { useEffect, useRef, useState, type ChangeEvent } from "react";
import { Camera, Eye, ImagePlus, Trash2 } from "lucide-react";
import { prepararDocumento } from "../documentoImagem";
import { urlDoDocumento } from "../services/documentos";

interface CampoDocumentoProps {
  id: string;
  rotulo: string; // ex.: "Frente do documento"
  obrigatorio?: boolean;
  caminhoAtual?: string | null; // arquivo já anexado (edição)
  podeVer?: boolean; // permissão membros.cpf
  onChange: (imagem: Blob | null) => void; // a imagem nova já preparada, ou nulo ao remover a escolha
  disabled?: boolean;
}

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function CampoDocumento({
  id,
  rotulo,
  obrigatorio = false,
  caminhoAtual = null,
  podeVer = false,
  onChange,
  disabled = false,
}: CampoDocumentoProps) {
  const cameraRef = useRef<HTMLInputElement>(null);
  const galeriaRef = useRef<HTMLInputElement>(null);
  const [previa, setPrevia] = useState<string | null>(null);
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
      const imagem = await prepararDocumento(arquivo);
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

  // Abre o documento já anexado em outra aba (endereço temporário)
  async function verAtual() {
    if (!caminhoAtual) return;
    setErro(null);
    const url = await urlDoDocumento(caminhoAtual);
    if (!url) return setErro("Não foi possível abrir o documento (sem permissão ou arquivo indisponível).");
    window.open(url, "_blank", "noopener,noreferrer");
  }

  const bloqueado = disabled || processando;

  return (
    <div className="space-y-2">
      <span className="text-sm font-medium text-slate-700">
        {rotulo}{" "}
        {obrigatorio ? (
          <span className="font-normal text-red-600" aria-hidden="true">
            *
          </span>
        ) : (
          <span className="font-normal text-slate-400">(opcional)</span>
        )}
      </span>

      <input
        ref={cameraRef}
        id={`${id}-camera`}
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
        id={`${id}-galeria`}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => void aoEscolher(e)}
      />

      <div className="flex items-start gap-4">
        {previa && (
          <div
            role="img"
            aria-label={`Nova imagem: ${rotulo}`}
            style={{ backgroundImage: `url(${previa})` }}
            className="h-28 w-40 shrink-0 rounded-lg bg-slate-100 bg-cover bg-center"
          />
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
              Remover a nova imagem
            </button>
          )}
          {!previa && caminhoAtual && podeVer && (
            <button type="button" className={classeBotao} onClick={() => void verAtual()} disabled={bloqueado}>
              <Eye className="h-4 w-4" aria-hidden="true" />
              Ver o documento anexado
            </button>
          )}
        </div>
      </div>

      {processando && <p className="text-xs text-slate-500">Preparando a imagem...</p>}
      {!previa && caminhoAtual && (
        <p className="text-xs text-emerald-700">Documento já anexado. Envie outra imagem só se quiser trocá-lo.</p>
      )}
      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
    </div>
  );
}
