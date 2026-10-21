import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { caminhosNaFila, movimentosDaAprovacao } from "./arquivos";

describe("arquivos do cadastro público", () => {
  it("monta os caminhos da fila", () => {
    expect(caminhosNaFila("abc")).toEqual({ foto: "abc/foto.jpg", frente: "abc/frente.jpg", verso: "abc/verso.jpg" });
  });
  it("move para a pasta do membro, nos buckets certos, com nomes únicos", () => {
    let n = 0;
    const m = movimentosDaAprovacao("ped", "mem", () => `u${++n}`);
    expect(m.foto.para).toEqual({ bucket: "fotos-membros", caminho: "mem/u1.jpg" });
    expect(m.frente.para).toEqual({ bucket: "documentos-membros", caminho: "mem/frente-u2.jpg" });
    expect(m.verso.para).toEqual({ bucket: "documentos-membros", caminho: "mem/verso-u3.jpg" });
    expect(m.foto.de).toEqual({ bucket: "cadastro-publico", caminho: "ped/foto.jpg" });
  });
});

import { moverTodos, type Movimento } from "./arquivos";

/** Armazenamento de mentira: guarda "bucket/caminho" num conjunto; o 3º movimento pode falhar. */
function adminFalso(falharNoMovimento: number | null) {
  const arquivos = new Set<string>(["cadastro-publico/p/foto.jpg", "cadastro-publico/p/frente.jpg", "cadastro-publico/p/verso.jpg"]);
  let chamadas = 0;
  const admin = {
    storage: {
      from: (bucket: string) => ({
        move: async (de: string, para: string, opcoes: { destinationBucket: string }) => {
          chamadas += 1;
          if (falharNoMovimento === chamadas) return { error: { message: "boom" } };
          if (!arquivos.delete(`${bucket}/${de}`)) return { error: { message: "não existe" } };
          arquivos.add(`${opcoes.destinationBucket}/${para}`);
          return { error: null };
        },
      }),
    },
  };
  return { admin: admin as never, arquivos };
}
const MOVS: Movimento[] = [
  { de: { bucket: "cadastro-publico", caminho: "p/foto.jpg" }, para: { bucket: "fotos-membros", caminho: "m/f.jpg" } },
  { de: { bucket: "cadastro-publico", caminho: "p/frente.jpg" }, para: { bucket: "documentos-membros", caminho: "m/fr.jpg" } },
  { de: { bucket: "cadastro-publico", caminho: "p/verso.jpg" }, para: { bucket: "documentos-membros", caminho: "m/ve.jpg" } },
];

describe("moverTodos", () => {
  it("move os três arquivos", async () => {
    const { admin, arquivos } = adminFalso(null);
    await moverTodos(admin, MOVS);
    expect([...arquivos].sort()).toEqual(["documentos-membros/m/fr.jpg", "documentos-membros/m/ve.jpg", "fotos-membros/m/f.jpg"]);
  });
  it("se o terceiro falhar, devolve os dois primeiros à fila", async () => {
    const { admin, arquivos } = adminFalso(3);
    await expect(moverTodos(admin, MOVS)).rejects.toThrow();
    expect([...arquivos].sort()).toEqual(["cadastro-publico/p/foto.jpg", "cadastro-publico/p/frente.jpg", "cadastro-publico/p/verso.jpg"]);
  });
});
