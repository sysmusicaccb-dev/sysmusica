/**
 * Sysmusica — Logo do sistema: por padrão a CLAVE DE SOL (em um quadrado na cor da marca). O administrador Master pode
 * trocá-la por uma imagem em Configurações; ela vale para todos (topo, menu e tela de entrada). NÃO usa a logomarca da
 * Congregação Cristã no Brasil. O nome do componente e a propriedade "comFundoBranco" ficam só por compatibilidade
 * (a propriedade é ignorada), para as telas que o usam não precisarem mudar.
 */
"use client";

import { useState } from "react";
import Image from "next/image";
import { cn } from "@/lib/cn";
import { urlPublicaDaLogo } from "@/modules/marca/services/marca";
import { useMarca } from "@/modules/marca/useMarca";

/** Desenho da clave de sol: ícone "music-clef-treble" do Pictogrammers (Material Design Icons), de licença livre. */
const DESENHO_CLAVE_DE_SOL =
  "M13 11V7.5L15.2 5.29C16 4.5 16.15 3.24 15.59 2.26C15.14 1.47 14.32 1 13.45 1C13.24 1 13 1.03 12.81 1.09C11.73 1.38 11 2.38 11 3.5V6.74L7.86 9.91C6.2 11.6 5.7 14.13 6.61 16.34C7.38 18.24 9.06 19.55 11 19.89V20.5C11 20.76 10.77 21 10.5 21H9V23H10.5C11.85 23 13 21.89 13 20.5V20C15.03 20 17.16 18.08 17.16 15.25C17.16 12.95 15.24 11 13 11M13 3.5C13 3.27 13.11 3.09 13.32 3.03C13.54 2.97 13.77 3.06 13.88 3.26C14 3.46 13.96 3.71 13.8 3.87L13 4.73V3.5M11 11.5C10.03 12.14 9.3 13.24 9.04 14.26L11 14.78V17.83C9.87 17.53 8.9 16.71 8.43 15.57C7.84 14.11 8.16 12.45 9.26 11.33L11 9.5V11.5M13 18V12.94C14.17 12.94 15.18 14.04 15.18 15.25C15.18 17 13.91 18 13 18Z";

interface LogoMarcaProps {
  /** Altura da imagem em pixels (a largura acompanha a proporção original). */
  altura?: number;
  /** Coloca a logo em uma plaquinha branca, para aparecer bem em fundos escuros. */
  comFundoBranco?: boolean;
  className?: string;
}

export default function LogoMarca({ altura = 40, className }: LogoMarcaProps) {
  const { marca } = useMarca();
  const [urlComErro, setUrlComErro] = useState<string | null>(null);
  const url = marca ? urlPublicaDaLogo(marca) : null;

  // Logo trocada em Configurações: a imagem dentro de uma placa branca (se não abrir, volta para a clave de sol)
  if (url && url !== urlComErro) {
    const lado = altura - 6;
    return (
      <span
        aria-hidden="true"
        className={cn("relative inline-block shrink-0 rounded-xl bg-white shadow-sm", className)}
        style={{ height: altura, width: altura }}
      >
        <Image
          src={url}
          alt=""
          width={lado}
          height={lado}
          unoptimized
          onError={() => setUrlComErro(url)}
          style={{ height: lado, width: lado, objectFit: "contain", position: "absolute", inset: 0, margin: "auto" }}
        />
      </span>
    );
  }

  // Padrão do sistema: clave de sol branca sobre a cor da marca
  // O desenho ocupa x de 6,16 a 17,16 e y de 1 a 23 (dentro de 24 x 24): o viewBox recorta exatamente essa área, então
  // as margens ficam iguais dos dois lados. Altura de 70% da placa (par), largura na proporção 1 : 2.
  const alturaDoDesenho = Math.round((altura * 0.7) / 2) * 2;
  const larguraDoDesenho = alturaDoDesenho / 2;
  return (
    <span
      aria-hidden="true"
      className={cn("relative inline-block shrink-0 rounded-xl bg-brand-600 text-white shadow-sm", className)}
      style={{ height: altura, width: altura }}
    >
      <svg
        viewBox="6.16 1 11 22"
        fill="currentColor"
        shapeRendering="geometricPrecision"
        style={{ position: "absolute", inset: 0, margin: "auto", height: alturaDoDesenho, width: larguraDoDesenho }}
      >
        <path d={DESENHO_CLAVE_DE_SOL} />
      </svg>
    </span>
  );
}
