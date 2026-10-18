/**
 * SysMúsica — Logomarca (emblema da Congregação Cristã no Brasil).
 * A imagem é escura sobre fundo claro. Por isso, em locais escuros ou no modo escuro, use "comFundoBranco":
 * ela aparece em uma plaquinha branca (cor fixa, que não muda com o tema).
 * Troque o arquivo em public/logo-ccb.png para mudar a imagem em todo o sistema.
 */
import Image from "next/image";
import { cn } from "@/lib/cn";
import { MARCA } from "@/lib/marca";

interface LogoMarcaProps {
  /** Altura da imagem em pixels (a largura acompanha a proporção original). */
  altura?: number;
  /** Coloca a logo em uma plaquinha branca, para aparecer bem em fundos escuros. */
  comFundoBranco?: boolean;
  className?: string;
}

export default function LogoMarca({ altura = 40, comFundoBranco = false, className }: LogoMarcaProps) {
  const largura = Math.round((altura * MARCA.logoLargura) / MARCA.logoAltura);

  return (
    <span
      className={cn("inline-flex shrink-0", comFundoBranco && "rounded-lg p-1.5", className)}
      style={comFundoBranco ? { backgroundColor: "#ffffff" } : undefined}
    >
      <Image
        src={MARCA.logoCaminho}
        alt={MARCA.logoDescricao}
        width={largura}
        height={altura}
        unoptimized
        style={{ height: altura, width: largura }}
      />
    </span>
  );
}
