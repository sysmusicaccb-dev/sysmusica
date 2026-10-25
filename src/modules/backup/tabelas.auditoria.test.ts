import { describe, expect, it } from "vitest";
import { GRUPOS_DADOS, TABELAS, ordenarParaGravar } from "./tabelas";

// Auditoria: tabelas acrescentadas ao backup (migração 0047)
describe("backup — tabelas da auditoria", () => {
  const novas = ["cadastro_publico_config", "qr_historico", "usuario_preferencias", "casas_oracao_historico"] as const;

  it("estão na lista e em exatamente um grupo de dados", () => {
    for (const nome of novas) {
      expect(TABELAS.some((t) => t.nome === nome)).toBe(true);
      expect(GRUPOS_DADOS.filter((g) => g.tabelas.includes(nome))).toHaveLength(1);
    }
  });

  it("o código do QR revogado é protegido e os históricos só aceitam devolver apagados", () => {
    const qr = TABELAS.find((t) => t.nome === "qr_historico");
    expect(qr?.sensiveis).toContain("token_hash");
    expect(qr?.somenteInserir).toBe(true);
    expect(TABELAS.find((t) => t.nome === "casas_oracao_historico")?.somenteInserir).toBe(true);
  });

  it("os pais vêm antes dos filhos na gravação", () => {
    const ordem = ordenarParaGravar(["qr_historico", "membros", "usuario_preferencias", "usuarios"]);
    expect(ordem.indexOf("membros")).toBeLessThan(ordem.indexOf("qr_historico"));
    expect(ordem.indexOf("usuarios")).toBeLessThan(ordem.indexOf("usuario_preferencias"));
  });
});
