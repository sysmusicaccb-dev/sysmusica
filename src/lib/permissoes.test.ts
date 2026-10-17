import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { CATALOGO_PERMISSOES } from "@/lib/permissoes";

// Junta o texto de TODAS as migrações (as permissões são criadas em mais de um arquivo)
function lerMigracoes(): string {
  const pasta = path.resolve(process.cwd(), "supabase/migrations");
  return readdirSync(pasta)
    .filter((arquivo) => arquivo.endsWith(".sql"))
    .sort()
    .map((arquivo) => readFileSync(path.join(pasta, arquivo), "utf-8"))
    .join("\n");
}

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

  it("todo módulo tem a permissão 'visualizar' (as demais ações dependem dela)", () => {
    const modulos = new Set(CATALOGO_PERMISSOES.map((permissao) => permissao.codigo.split(".")[0]));
    const codigos = CATALOGO_PERMISSOES.map((permissao) => permissao.codigo as string);
    for (const modulo of modulos) {
      expect(codigos, `falta ${modulo}.visualizar`).toContain(`${modulo}.visualizar`);
    }
  });

  it("todo código existe no catálogo do banco (supabase/migrations)", () => {
    const sql = lerMigracoes();
    for (const { codigo } of CATALOGO_PERMISSOES) {
      expect(sql, `permissão ausente nas migrações: ${codigo}`).toContain(`'${codigo}'`);
    }
  });
});
