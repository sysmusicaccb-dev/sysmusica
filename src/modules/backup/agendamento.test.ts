import { describe, expect, it } from "vitest";
import {
  PADRAO_AGENDAMENTO,
  escolherTipo,
  excedentes,
  inicioDoDiaSalvador,
  lerEntradaAgendamento,
  partesSalvador,
  proximoBackup,
  validarAgendamento,
  type ConfigAgendamento,
} from "./agendamento";

const ligado: ConfigAgendamento = { ...PADRAO_AGENDAMENTO, ativo: true };
// Cron das 06:00 UTC = 03:00 em Salvador
const cron = (iso: string) => new Date(`${iso}T06:00:00Z`);

describe("datas em Salvador", () => {
  it("usa o dia de Salvador, não o de UTC", () => {
    // 01:00 UTC de 20/10 ainda é 22:00 de 19/10 em Salvador
    expect(partesSalvador(new Date("2026-10-20T01:00:00Z"))).toMatchObject({ dia: 19, mes: 10 });
    expect(partesSalvador(new Date("2026-10-20T03:00:00Z"))).toMatchObject({ dia: 20 });
  });
  it("início do dia é 03:00 UTC", () => {
    expect(inicioDoDiaSalvador(new Date("2026-10-20T01:00:00Z")).toISOString()).toBe("2026-10-19T03:00:00.000Z");
    expect(inicioDoDiaSalvador(new Date("2026-10-20T15:00:00Z")).toISOString()).toBe("2026-10-20T03:00:00.000Z");
  });
});

describe("escolherTipo", () => {
  it("devolve nulo se o agendamento está desligado", () => {
    expect(escolherTipo({ ...ligado, ativo: false }, cron("2026-11-01"))).toBeNull();
  });
  it("mensal vence quinzenal, semanal e diário", () => {
    // 01/11/2026 é domingo: valem mensal, quinzenal, semanal e diário
    expect(escolherTipo(ligado, cron("2026-11-01"))).toBe("mensal");
  });
  it("quinzenal nos dias 1 e 16 quando o mensal não vale", () => {
    expect(escolherTipo({ ...ligado, mensal_ativo: false }, cron("2026-11-01"))).toBe("quinzenal");
    expect(escolherTipo(ligado, cron("2026-11-16"))).toBe("quinzenal");
  });
  it("semanal no dia da semana escolhido", () => {
    expect(escolherTipo(ligado, cron("2026-10-18"))).toBe("semanal"); // domingo
    expect(escolherTipo({ ...ligado, semanal_dia: 3 }, cron("2026-10-21"))).toBe("semanal"); // quarta
  });
  it("diário nos demais dias, e nulo se nada vale", () => {
    expect(escolherTipo(ligado, cron("2026-10-20"))).toBe("diario"); // terça
    expect(escolherTipo({ ...ligado, diario_ativo: false }, cron("2026-10-20"))).toBeNull();
  });
  it("respeita o dia do mês escolhido para o mensal", () => {
    expect(escolherTipo({ ...ligado, mensal_dia: 10 }, cron("2026-10-10"))).toBe("mensal");
    expect(escolherTipo({ ...ligado, mensal_dia: 10 }, cron("2026-11-01"))).toBe("quinzenal");
  });
});

describe("proximoBackup", () => {
  it("é nulo com o agendamento desligado", () => {
    expect(proximoBackup(PADRAO_AGENDAMENTO, new Date("2026-10-19T12:00:00Z"))).toBeNull();
  });
  it("antes das 03:00 de Salvador, o próximo é hoje às 06:00 UTC", () => {
    const p = proximoBackup(ligado, new Date("2026-10-20T04:00:00Z")); // 01:00 em Salvador, terça
    expect(p?.quando.toISOString()).toBe("2026-10-20T06:00:00.000Z");
    expect(p?.tipo).toBe("diario");
  });
  it("depois das 03:00 de Salvador, o próximo é amanhã", () => {
    const p = proximoBackup(ligado, new Date("2026-10-20T09:00:00Z")); // 06:00 em Salvador
    expect(p?.quando.toISOString()).toBe("2026-10-21T06:00:00.000Z");
  });
  it("à noite em Salvador (já é o dia seguinte em UTC), não pula um dia", () => {
    const p = proximoBackup(ligado, new Date("2026-10-21T01:00:00Z")); // 22:00 de terça em Salvador
    expect(p?.quando.toISOString()).toBe("2026-10-21T06:00:00.000Z");
  });
});

describe("excedentes (retenção)", () => {
  const mk = (n: number) => ({ id: `b${n}`, criado_em: `2026-10-${String(n).padStart(2, "0")}T06:00:00Z` });
  const dez = [3, 1, 10, 5, 2, 9, 4, 8, 7, 6].map(mk);
  it("apaga só os mais antigos além do limite", () => {
    expect(excedentes(dez, 7).map((l) => l.id).sort()).toEqual(["b1", "b2", "b3"]);
  });
  it("não apaga nada se há menos que o limite", () => {
    expect(excedentes(dez.slice(0, 3), 7)).toEqual([]);
  });
  it("sempre mantém pelo menos um, mesmo com limite zero ou inválido", () => {
    expect(excedentes(dez, 0)).toHaveLength(9);
    expect(excedentes(dez, -5)).toHaveLength(9);
  });
});

describe("validação", () => {
  const corpo = { ...ligado };
  it("lê um corpo válido e recusa formatos errados", () => {
    expect(lerEntradaAgendamento(corpo)).toEqual(corpo);
    expect(lerEntradaAgendamento(null)).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, diario_retencao: 0 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, diario_retencao: 91 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, diario_retencao: 7.5 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, semanal_dia: 7 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, mensal_dia: 29 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, ativo: "sim" })).toBeNull();
  });
  it("não deixa ligar o agendamento sem nenhum tipo", () => {
    const nenhum = { ...ligado, diario_ativo: false, semanal_ativo: false, quinzenal_ativo: false, mensal_ativo: false };
    expect(validarAgendamento(nenhum)).toMatch(/pelo menos um/);
    expect(validarAgendamento({ ...nenhum, ativo: false })).toBeNull();
    expect(validarAgendamento(ligado)).toBeNull();
  });
});
