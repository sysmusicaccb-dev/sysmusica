import { describe, expect, it } from "vitest";
import { CADASTRO_VAZIO, ESTADOS_CIVIS } from "./cadastroMusical";
import {
  AVISO_BATISMO_MENOR,
  ESTADO_CIVIL_CASADO,
  SEM_REGRAS,
  aplicarRegrasDoCargo,
  avisoBatismoDeMenor,
  idadeEmAnos,
  regrasDoCargo,
} from "./regrasCargo";

describe("regrasDoCargo", () => {
  it("o estado civil imposto existe na lista do formulário", () => {
    expect((ESTADOS_CIVIS as readonly string[]).includes(ESTADO_CIVIL_CASADO)).toBe(true);
  });

  it("Ancião e Diácono: batizado, casado e selado", () => {
    for (const nome of ["Ancião", "Diácono"]) {
      expect(regrasDoCargo(nome, "")).toEqual({ batizado: true, casado: true, selado: true });
    }
  });

  it("Cooperadores, Encarregado Regional e Examinadora: batizado e casado", () => {
    for (const nome of [
      "Cooperador do Ofício Ministerial",
      "Cooperador da Reunião de Jovens e Menores",
      "Cooperador de Jovens e Menores",
      "Encarregado Regional",
      "Examinadora",
    ]) {
      expect(regrasDoCargo(nome, "")).toEqual({ batizado: true, casado: true, selado: false });
    }
  });

  it("Encarregado Local, Instrutor(a) e Secretário da Música: só batizado", () => {
    for (const nome of ["Encarregado Local", "Instrutor", "Instrutora", "Instrutor (a)", "Secretário da Música"]) {
      expect(regrasDoCargo(nome, "")).toEqual({ batizado: true, casado: false, selado: false });
    }
  });

  it("Músico e Organista: batizado só em Oficializado e Culto Oficial", () => {
    for (const nome of ["Músico", "Organista"]) {
      expect(regrasDoCargo(nome, "OFICIALIZADO").batizado).toBe(true);
      expect(regrasDoCargo(nome, "CULTO_OFICIAL").batizado).toBe(true);
      expect(regrasDoCargo(nome, "RJM").batizado).toBe(false);
      expect(regrasDoCargo(nome, "").batizado).toBe(false);
      expect(regrasDoCargo(nome, "OFICIALIZADO").casado).toBe(false);
    }
  });

  it("cargo sem regra, vazio ou desconhecido: tudo livre", () => {
    expect(regrasDoCargo("Candidato (a)", "")).toEqual(SEM_REGRAS);
    expect(regrasDoCargo(undefined, "")).toEqual(SEM_REGRAS);
    expect(regrasDoCargo("", "OFICIALIZADO")).toEqual(SEM_REGRAS);
  });
});

describe("aplicarRegrasDoCargo", () => {
  it("preenche os campos que o cargo decide e mantém os outros", () => {
    const base = { ...CADASTRO_VAZIO, sexo: "Masculino", data_batismo: "2000-05-01", estado_civil: "Solteiro (a)" };
    const r = aplicarRegrasDoCargo(base, { batizado: true, casado: true, selado: false });
    expect(r.batizado).toBe("sim");
    expect(r.estado_civil).toBe(ESTADO_CIVIL_CASADO);
    expect(r.selado).toBe("");
    expect(r.sexo).toBe("Masculino");
    expect(r.data_batismo).toBe("2000-05-01");
  });

  it("não troca o objeto quando nada muda", () => {
    expect(aplicarRegrasDoCargo(CADASTRO_VAZIO, SEM_REGRAS)).toBe(CADASTRO_VAZIO);
    const pronto = { ...CADASTRO_VAZIO, batizado: "sim" as const };
    expect(aplicarRegrasDoCargo(pronto, { batizado: true, casado: false, selado: false })).toBe(pronto);
  });
});

describe("idade e aviso de batismo de menor", () => {
  it("calcula a idade em anos completos", () => {
    expect(idadeEmAnos("2015-10-23", "2026-10-22")).toBe(10);
    expect(idadeEmAnos("2014-10-22", "2026-10-22")).toBe(12);
    expect(idadeEmAnos("", "2026-10-22")).toBeNull();
    expect(idadeEmAnos("2015-02-31", "2026-10-22")).toBeNull();
  });

  it("avisa só abaixo de 12 anos e quando o batismo não é automático", () => {
    expect(avisoBatismoDeMenor(SEM_REGRAS, "2018-01-01", "2026-10-22")).toBe(AVISO_BATISMO_MENOR);
    expect(avisoBatismoDeMenor(SEM_REGRAS, "2014-10-22", "2026-10-22")).toBeNull();
    expect(avisoBatismoDeMenor(SEM_REGRAS, "", "2026-10-22")).toBeNull();
    expect(avisoBatismoDeMenor({ batizado: true, casado: false, selado: false }, "2018-01-01", "2026-10-22")).toBeNull();
  });
});
