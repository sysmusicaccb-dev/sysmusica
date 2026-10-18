/**
 * SysMúsica — Etiqueta da situação de verificação de um backup: "A verificar" (rosa suave), "Verificado"
 * (verde suave) ou "Falha na verificação". Ao passar o mouse mostra quem verificou e quando.
 */
import { descreverEtiquetaVerificacao } from "../regras";
import type { RegistroBackup } from "../tipos";

export default function EtiquetaVerificacao({ backup }: { backup: RegistroBackup }) {
  const etiqueta = descreverEtiquetaVerificacao(backup);

  return (
    <span
      title={etiqueta.dica}
      className={`mt-1 block w-fit rounded-full px-2 py-0.5 text-xs font-medium ${etiqueta.classe}`}
    >
      {etiqueta.texto}
    </span>
  );
}
