/** Sysmusica — Testes do topo azul: atalhos por permissão e resumo do evento do dia. */
import { describe, expect, it } from "vitest";
import type { CodigoPermissao } from "@/lib/permissoes";
import { atalhosDoTopo, formatarRelogioDoTopo, resumoEventoDoTopo } from "./topo";

const podeTudo = () => true;
const podeSo = (...permitidas: CodigoPermissao[]) => (p: CodigoPermissao) => permitidas.includes(p);

describe("atalhosDoTopo", () => {
  it("o topo não tem mais os atalhos Portaria e Relatório, nem para quem pode tudo", () => {
    expect(atalhosDoTopo(podeTudo)).toEqual([]);
  });

  it("não mostra nada sem permissão", () => {
    expect(atalhosDoTopo(podeSo())).toEqual([]);
  });

  it("nem com as permissões de Portaria e Relatório", () => {
    expect(atalhosDoTopo(podeSo("portaria.visualizar", "relatorios.visualizar"))).toEqual([]);
  });
});

describe("formatarRelogioDoTopo", () => {
  it("mostra dia da semana, data e hora em 24h no fuso da Bahia", () => {
    // 04:04 UTC = 01:04 na Bahia (UTC-3), sexta-feira
    expect(formatarRelogioDoTopo(new Date("2026-10-23T04:04:00Z"))).toEqual({ dia: "Sex, 23/10/2026", hora: "01:04" });
  });

  it("meia-noite é 00:00 (nunca 24:00) e à tarde usa 24 horas", () => {
    expect(formatarRelogioDoTopo(new Date("2026-10-23T03:00:00Z")).hora).toBe("00:00");
    expect(formatarRelogioDoTopo(new Date("2026-10-23T21:30:00Z")).hora).toBe("18:30");
  });

  it("usa a data da Bahia, não a do servidor (02:00 UTC ainda é o dia anterior aqui)", () => {
    expect(formatarRelogioDoTopo(new Date("2026-10-23T02:00:00Z")).dia).toBe("Qui, 22/10/2026");
  });
});

describe("resumoEventoDoTopo", () => {
  it("monta título, local em maiúsculas (cidade - casa de oração) e data", () => {
    const resumo = resumoEventoDoTopo({
      id: "1",
      tipo: "Ensaio Regional",
      local_evento: "Salão",
      data_evento: "2026-10-11T12:00:00Z",
      cidade: "Gandu",
      casa_oracao_nome: "Central",
    });
    expect(resumo).toEqual({ titulo: "Ensaio Regional", local: "GANDU - CENTRAL", dataIso: "2026-10-11T12:00:00Z" });
  });

  it("usa o local do evento quando não há casa de oração e ignora campos vazios", () => {
    const resumo = resumoEventoDoTopo({ tipo: "Reunião", local_evento: "Salão", data_evento: "2026-10-11T12:00:00Z", cidade: null });
    expect(resumo?.local).toBe("SALÃO");
  });

  it("devolve null sem evento ou sem data", () => {
    expect(resumoEventoDoTopo(undefined)).toBeNull();
    expect(resumoEventoDoTopo({ tipo: "Ensaio" })).toBeNull();
  });
});
