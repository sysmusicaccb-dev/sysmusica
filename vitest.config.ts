/**
 * Sysmusica — Configuração dos testes (Vitest).
 * O alias "@" aponta para src/, igual ao tsconfig, para os testes usarem os mesmos imports.
 */
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": path.resolve(process.cwd(), "src") } },
  test: { environment: "node", include: ["src/**/*.test.ts"] },
});
