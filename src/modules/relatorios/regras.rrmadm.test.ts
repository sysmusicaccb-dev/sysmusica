/** SysMúsica — Testes das listas encadeadas RRM › RA › ADM › Setor › Casa de Oração dos filtros de relatório. */
import { describe, expect, it } from "vitest";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import { FILTROS_VAZIOS, opcoesAdm, opcoesCasaOracao, opcoesRegiao, opcoesRrm, opcoesSetor, resumoFiltros, rotulosDosFiltros } from "./regras";
import { DEFINICOES_RELATORIO } from "./catalogo";

const no = (id: string, nome: string, nivel: string, parent_id: string | null) => ({ id, nome, nivel, parent_id, ativo: true });

const NOS = [
  no("e1", "Bahia", "ESTADO", null),
  no("r1", "RRM Conquista", "RRM", "e1"),
  no("r2", "RRM Salvador", "RRM", "e1"),
  no("ra1", "RA Jequié", "RA", "r1"),
  no("ra2", "RA Salvador", "RA", "r2"),
  no("a1", "ADM Ipiaú", "ADM", "ra1"),
  no("a2", "ADM Jequié", "ADM", "ra1"),
  no("s1", "Setor 1", "SETOR", "a1"),
  no("c1", "Casa do Setor", "CASA_ORACAO", "s1"),
  no("c2", "Casa Direta", "CASA_ORACAO", "a1"),
  no("c3", "Casa da Outra ADM", "CASA_ORACAO", "a2"),
] as unknown as NoOrganizacao[];

const ids = (lista: { id: string }[]) => lista.map((item) => item.id).sort();

describe("filtros de organização dos relatórios", () => {
  it("lista as RRMs e filtra as RAs pela RRM escolhida", () => {
    expect(ids(opcoesRrm(NOS))).toEqual(["r1", "r2"]);
    expect(ids(opcoesRegiao(NOS))).toEqual(["ra1", "ra2"]);
    expect(ids(opcoesRegiao(NOS, "r1"))).toEqual(["ra1"]);
  });

  it("lista as ADMs só depois de escolher a RA", () => {
    expect(opcoesAdm(NOS, "")).toEqual([]);
    expect(ids(opcoesAdm(NOS, "ra1"))).toEqual(["a1", "a2"]);
  });

  it("limita setores e casas à ADM escolhida", () => {
    expect(ids(opcoesSetor(NOS, "ra1"))).toEqual(["s1"]);
    expect(opcoesSetor(NOS, "ra1", "a2")).toEqual([]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", ""))).toEqual(["c1", "c2", "c3"]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", "", "a1"))).toEqual(["c1", "c2"]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", "", "a2"))).toEqual(["c3"]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", "s1", "a1"))).toEqual(["c1"]);
  });

  it("mostra RRM e ADM no resumo dos filtros", () => {
    const filtros = { ...FILTROS_VAZIOS, rrmId: "r1", regiaoId: "ra1", admId: "a1" };
    const opcoes = { organizacao: NOS, cargos: [], instrumentos: [], eventos: [] };
    const rotulos = rotulosDosFiltros(filtros, opcoes);
    expect(rotulos.rrm).toBe("RRM Conquista");
    expect(rotulos.adm).toBe("ADM Ipiaú");
    const membros = DEFINICOES_RELATORIO.find((d) => d.id === "membros");
    if (!membros) throw new Error("Relatório de membros não encontrado no catálogo.");
    expect(resumoFiltros(membros, filtros, rotulos)).toBe("RRM: RRM Conquista · RA: RA Jequié · ADM: ADM Ipiaú");
  });

  it("os relatórios de presença, membros e eventos oferecem os filtros RRM e ADM", () => {
    for (const id of ["presenca", "membros", "eventos"]) {
      const filtros = DEFINICOES_RELATORIO.find((d) => d.id === id)?.filtros ?? [];
      expect(filtros).toContain("rrm");
      expect(filtros).toContain("adm");
    }
  });
});
