"use client";

/**
 * Sysmusica — Fotografia do membro (miniatura ou retrato grande).
 * Busca a URL temporária da foto; sem foto (ou se falhar), mostra um espaço reservado.
 * Usa um fundo de imagem (e não <img>) com texto alternativo para leitores de tela.
 */
import { useEffect, useState } from "react";
import { User } from "lucide-react";
import { cn } from "@/lib/cn";
import { urlDaFoto } from "../services/fotos";

interface FotoMembroProps {
  caminho: string | null;
  nome: string;
  tamanho?: "pequena" | "grande";
}

export default function FotoMembro({ caminho, nome, tamanho = "pequena" }: FotoMembroProps) {
  // Guarda junto o caminho a que a URL pertence (evita mostrar a foto de outro membro por um instante)
  const [carregada, setCarregada] = useState<{ caminho: string; url: string | null } | null>(null);

   
  useEffect(() => {
    if (!caminho) return;
    let cancelado = false;
    void urlDaFoto(caminho).then((url) => {
      if (!cancelado) setCarregada({ caminho, url });
    });
    return () => {
      cancelado = true;
    };
  }, [caminho]);
   

  const url = caminho && carregada?.caminho === caminho ? carregada.url : null;
  const medidas = tamanho === "grande" ? "h-44 w-36" : "h-12 w-10";

  return (
    <div
      role="img"
      aria-label={url ? `Fotografia de ${nome}` : `${nome}: sem fotografia`}
      style={url ? { backgroundImage: `url(${url})` } : undefined}
      className={cn(
        "flex shrink-0 items-center justify-center overflow-hidden rounded-xl bg-slate-100 bg-cover bg-center text-slate-400",
        medidas
      )}
    >
      {!url && <User className={tamanho === "grande" ? "h-14 w-14" : "h-5 w-5"} aria-hidden="true" />}
    </div>
  );
}
