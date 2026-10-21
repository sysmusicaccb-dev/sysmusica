import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
vi.mock("@/modules/administracao/server/clienteAdmin", () => ({ clienteAdmin: () => ({}) }));
import { limparCadastroPublico } from "./limpeza";

function adminFalso(opcoes: { removerFalha?: boolean; pastas?: string[] }) {
  const chamadas: Array<{ fn: string; args: unknown }> = [];
  const pastas = opcoes.pastas ?? ["a", "b"];
  const admin = {
    rpc: async (fn: string, args?: unknown) => {
      chamadas.push({ fn, args });
      if (fn === "limpeza_cadastro_publico") return { data: { pastas, para_marcar: ["b"], abandonados: ["a"] }, error: null };
      return { data: 1, error: null };
    },
    storage: {
      from: () => ({
        remove: async (lista: string[]) =>
          opcoes.removerFalha ? { data: null, error: { message: "boom" } } : { data: lista.map((name) => ({ name })), error: null },
      }),
    },
  };
  return { admin: admin as never, chamadas };
}

describe("limparCadastroPublico", () => {
  it("apaga os 3 arquivos de cada pasta e depois marca os pedidos", async () => {
    const { admin, chamadas } = adminFalso({});
    const r = await limparCadastroPublico(admin);
    expect(r).toEqual({ pastas: 2, arquivos_apagados: 6, pedidos_zerados: 1, falhou: false });
    const marcar = chamadas.find((c) => c.fn === "marcar_cadastros_limpos");
    expect(marcar?.args).toEqual({ p_ids: ["b"], p_abandonados: ["a"] });
  });
  it("se não conseguir apagar os arquivos, NÃO zera os dados (tenta amanhã)", async () => {
    const { admin, chamadas } = adminFalso({ removerFalha: true });
    const r = await limparCadastroPublico(admin);
    expect(r.falhou).toBe(true);
    expect(chamadas.some((c) => c.fn === "marcar_cadastros_limpos")).toBe(false);
  });
  it("sem nada a limpar, não chama o banco de novo", async () => {
    const admin = { rpc: async () => ({ data: { pastas: [], para_marcar: [], abandonados: [] }, error: null }), storage: { from: () => ({ remove: async () => ({ data: [], error: null }) }) } };
    const r = await limparCadastroPublico(admin as never);
    expect(r).toEqual({ pastas: 0, arquivos_apagados: 0, pedidos_zerados: 0, falhou: false });
  });
});
