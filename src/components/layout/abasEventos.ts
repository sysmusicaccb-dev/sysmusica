/**
 * Sysmusica — Abas da tela de Eventos (regra pura): Eventos | Tipo do Evento | Gestão de portarias.
 * (A aba Portaria saiu: ler QR Code e buscar pelo nome agora é o botão da tela Registrar Presença.)
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
  // Cadastro dos tipos de evento (Ensaio Regional, Culto...): fica aqui como aba, não mais solto no menu lateral
  if (pode("tipoevento.visualizar")) abas.push({ href: "/tipos-evento", rotulo: "Tipo do Evento" });
  // Mesma regra do layout de /portarias: visualiza, cria ou aprova
  if (pode("portarias.visualizar") || pode("portarias.criar") || pode("portarias.aprovar")) {
    abas.push({ href: "/portarias", rotulo: "Gestão de Portarias" });
  }

  // Configurações: encerrar sozinho e horas (só quem tem eventos.configurar)
  if (pode("eventos.configurar")) abas.push({ href: "/configuracao-eventos", rotulo: "Configurações" });

  // Uma aba só não precisa de barra
  return abas.length > 1 ? abas : [];
}
