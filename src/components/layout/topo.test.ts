/** Sysmusica — Testes do topo azul: atalhos por permissão e resumo do evento do dia. */
import { describe, expect, it } from "vitest";
import type { CodigoPermissao } from "@/lib/permissoes";
import { atalhosDoTopo, resumoEventoDoTopo } from "./topo";

const podeTudo = () => true;
const podeSo = (...permitidas: CodigoPermissao[]) => (p: CodigoPermissao) => permitidas.includes(p);

describe("atalhosDoTopo", () => {
  it("mostra Portaria e Relatório para quem tem as duas permissões", () => {
    expect(atalhosDoTopo(podeTudo).map((a) => a.rotulo)).toEqual(["Portaria", "Relatório"]);
  });

  it("mostra só o que o usuário pode abrir", () => {
    expect(atalhosDoTopo(podeSo("relatorios.visualizar")).map((a) => a.href)).toEqual(["/relatorios"]);
    expect(atalhosDoTopo(podeSo("portaria.visualizar")).map((a) => a.href)).toEqual(["/portaria"]);
  });

  it("não mostra nada sem permissão", () => {
    expect(atalhosDoTopo(podeSo())).toEqual([]);
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
