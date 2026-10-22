"use client";

/**
 * Sysmusica — Janela de Configurações (painel lateral com a aparência do sistema).
 * É desenhada na casca do sistema (AppShell) e NÃO dentro da barra do topo: a barra tem efeito de
 * desfoque, e isso prenderia o painel (que é fixo na tela) dentro dela. O botão que abre fica na barra.
 */
import Drawer from "@/components/ui/Drawer";
import PainelAparencia from "./PainelAparencia";

interface JanelaConfiguracoesProps {
  aberto: boolean;
  onFechar: () => void;
}

export default function JanelaConfiguracoes({ aberto, onFechar }: JanelaConfiguracoesProps) {
  return (
    <Drawer
      aberto={aberto}
      onFechar={onFechar}
      titulo="Configurações"
      descricao="Aparência do sistema: modo, cor e tamanho da letra. As mudanças valem na hora."
    >
      {aberto && <PainelAparencia />}
    </Drawer>
  );
}
