/**
 * SysMúsica — Abas da tela de Eventos (regra pura): Eventos | Gestão de portarias | Portaria.
 * Cada aba é uma tela que já existe (mesma rota e mesma permissão); aqui só se decide QUAIS abas a pessoa vê.
 * As abas existem só para quem tem a permissão de Eventos e acesso a pelo menos mais uma tela: quem não tem
 * Eventos (ex.: grupo Portaria) continua com os itens próprios no menu e não vê barra de abas.
 */
import type { CodigoPermissao } from "@/lib/permissoes";

export interface AbaEvento {
  href: string;
  rotulo: string;
}

export function abasDeEventos(pode: (permissao: CodigoPermissao) => boolean): AbaEvento[] {
  if (!pode("eventos.visualizar")) return [];

  const abas: AbaEvento[] = [{ href: "/eventos", rotulo: "Eventos" }];
  // Mesma regra do layout de /portarias: visualiza, cria ou aprova
  if (pode("portarias.visualizar") || pode("portarias.criar") || pode("portarias.aprovar")) {
    abas.push({ href: "/portarias", rotulo: "Gestão de portarias" });
  }
  if (pode("portaria.visualizar")) abas.push({ href: "/portaria", rotulo: "Portaria" });

  // Uma aba só não precisa de barra
  return abas.length > 1 ? abas : [];
}
