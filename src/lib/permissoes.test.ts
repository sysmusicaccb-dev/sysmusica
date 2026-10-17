import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { CATALOGO_PERMISSOES } from "@/lib/permissoes";

describe("CATALOGO_PERMISSOES", () => {
  it("não tem códigos repetidos", () => {
    const codigos = CATALOGO_PERMISSOES.map((permissao) => permissao.codigo);
    expect(new Set(codigos).size).toBe(codigos.length);
  });

  it("todo código segue o formato modulo.acao em minúsculas", () => {
    for (const { codigo } of CATALOGO_PERMISSOES) {
      expect(codigo).toMatch(/^[a-z]+\.[a-z]+$/);
    }
  });

  it("todo código existe no catálogo do banco (supabase/migrations/0002_rbac.sql)", () => {
    const sql = readFileSync(path.resolve(process.cwd(), "supabase/migrations/0002_rbac.sql"), "utf-8");
    for (const { codigo } of CATALOGO_PERMISSOES) {
      expect(sql, `permissão ausente no SQL: ${codigo}`).toContain(`'${codigo}'`);
    }
  });
});
