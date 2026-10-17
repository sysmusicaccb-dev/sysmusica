"use client";

/**
 * SysMúsica — QR Code do membro (conteúdo do painel lateral).
 *
 * Mostra a imagem do QR Code (gerada no navegador a partir do código que o servidor devolveu),
 * permite copiar o código e baixar a imagem. Quem tem a permissão de substituição também vê o bloco
 * "Substituir QR Code": exige justificativa e confirmação, e o código antigo deixa de funcionar na hora.
 * O QR Code identifica o cadastro, mas NÃO prova quem o apresenta: a portaria confere a foto.
 */
import { useState } from "react";
import { Copy, Download } from "lucide-react";
import Button from "@/components/ui/Button";
import { normalizarTexto } from "@/lib/texto";

interface QrMembroProps {
  nome: string;
  congregacao: string;
  imagem: string; // data URL (PNG)
  conteudo: string; // texto gravado no QR Code
  podeSubstituir: boolean;
  /** Substitui o QR Code (a tela recarrega a imagem em seguida). Deve lançar erro se falhar. */
  onSubstituir: (justificativa: string) => Promise<void>;
}

export default function QrMembro({
  nome,
  congregacao,
  imagem,
  conteudo,
  podeSubstituir,
  onSubstituir,
}: QrMembroProps) {
  const [copiado, setCopiado] = useState(false);
  const [justificativa, setJustificativa] = useState("");
  const [ciente, setCiente] = useState(false);
  const [substituindo, setSubstituindo] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  // Nome do arquivo baixado: "qr-maria-da-silva.png"
  const nomeArquivo = `qr-${normalizarTexto(nome).replace(/\s+/g, "-")}.png`;
  const justificativaValida = justificativa.trim().length >= 10;

  async function copiarCodigo() {
    try {
      await navigator.clipboard.writeText(conteudo);
      setCopiado(true);
      window.setTimeout(() => setCopiado(false), 2000);
    } catch {
      setErro("Não foi possível copiar. Selecione e copie o código manualmente.");
    }
  }

  async function substituir() {
    if (substituindo || !ciente || !justificativaValida) return;
    setErro(null);
    setSubstituindo(true);
    try {
      await onSubstituir(justificativa.trim());
      setJustificativa("");
      setCiente(false);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível substituir o QR Code.");
    } finally {
      setSubstituindo(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="text-center">
        {/* eslint-disable-next-line @next/next/no-img-element -- imagem gerada no navegador (data URL) */}
        <img
          src={imagem}
          alt={`QR Code de ${nome}`}
          width={256}
          height={256}
          className="mx-auto h-64 w-64 rounded-xl border border-slate-200 bg-white p-2"
        />
        <p className="mt-3 font-semibold text-slate-900">{nome}</p>
        <p className="text-sm text-slate-500">{congregacao}</p>
        <p className="mt-1 text-xs text-slate-400">Código terminado em {conteudo.slice(-6)}</p>
      </div>

      <div className="flex flex-col gap-2 sm:flex-row">
        <Button variante="secundario" icone={Copy} onClick={() => void copiarCodigo()} className="flex-1">
          {copiado ? "Código copiado!" : "Copiar código"}
        </Button>
        <a
          href={imagem}
          download={nomeArquivo}
          className="inline-flex flex-1 items-center justify-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
        >
          <Download className="h-4 w-4" aria-hidden="true" />
          Baixar imagem
        </a>
      </div>

      <p className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-600">
        O QR Code identifica o cadastro, mas não prova quem o apresenta: na portaria, confira sempre a
        fotografia. Ele não contém nome, CPF ou outros dados pessoais.
      </p>

      {podeSubstituir && (
        <section className="space-y-3 rounded-xl border border-red-200 bg-red-50/50 p-4">
          <div>
            <h3 className="text-sm font-semibold text-slate-900">Substituir QR Code</h3>
            <p className="mt-0.5 text-xs text-slate-600">
              O QR Code atual deixa de funcionar imediatamente. Use quando o código foi compartilhado
              indevidamente ou perdido. A operação fica registrada na auditoria.
            </p>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="justificativa-qr" className="text-sm font-medium text-slate-700">
              Justificativa
            </label>
            <textarea
              id="justificativa-qr"
              rows={3}
              maxLength={300}
              value={justificativa}
              onChange={(e) => setJustificativa(e.target.value)}
              disabled={substituindo}
              placeholder="Ex: Membro perdeu o celular e o código foi compartilhado."
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
            />
            <p className="text-xs text-slate-500">Mínimo de 10 caracteres.</p>
          </div>

          <label className="flex items-start gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={ciente}
              onChange={(e) => setCiente(e.target.checked)}
              disabled={substituindo}
              className="mt-0.5 h-4 w-4 rounded border-slate-300 text-red-600 focus:ring-red-300"
            />
            Estou ciente de que o QR Code atual será invalidado.
          </label>

          <Button
            variante="perigo"
            onClick={() => void substituir()}
            disabled={substituindo || !ciente || !justificativaValida}
            className="w-full"
          >
            {substituindo ? "Substituindo..." : "Gerar novo QR Code"}
          </Button>
        </section>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
    </div>
  );
}
