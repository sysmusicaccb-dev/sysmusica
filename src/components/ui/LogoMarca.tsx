/**
 * Sysmusica — Símbolo do sistema (nota musical em um quadrado de cor da marca). NÃO usa mais a logomarca da
 * Congregação Cristã no Brasil. O nome do componente e a propriedade "comFundoBranco" ficam só por compatibilidade
 * (a propriedade é ignorada), para as telas que o usam não precisarem mudar.
 */
import { Music } from "lucide-react";
import { cn } from "@/lib/cn";

interface LogoMarcaProps {
  /** Altura da imagem em pixels (a largura acompanha a proporção original). */
  altura?: number;
  /** Coloca a logo em uma plaquinha branca, para aparecer bem em fundos escuros. */
  comFundoBranco?: boolean;
  className?: string;
}

export default function LogoMarca({ altura = 40, className }: LogoMarcaProps) {
  return (
    <span
      aria-hidden="true"
      className={cn("inline-flex shrink-0 items-center justify-center rounded-xl bg-brand-600 text-white shadow-sm", className)}
      style={{ height: altura, width: altura }}
    >
      <Music style={{ height: Math.round(altura * 0.55), width: Math.round(altura * 0.55) }} />
    </span>
  );
}
