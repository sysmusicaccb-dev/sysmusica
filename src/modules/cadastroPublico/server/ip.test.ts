import { describe, expect, it } from "vitest";
import { extrairIp, hashDoIp } from "./ip";

describe("extrairIp", () => {
  it("usa o primeiro IP de x-forwarded-for", () => {
    expect(extrairIp(new Headers({ "x-forwarded-for": "203.0.113.5, 10.0.0.1" }))).toBe("203.0.113.5");
  });
  it("cai para x-real-ip", () => {
    expect(extrairIp(new Headers({ "x-real-ip": "198.51.100.7" }))).toBe("198.51.100.7");
  });
  it("sem cabeçalho ou com lixo enorme, devolve nulo", () => {
    expect(extrairIp(new Headers())).toBeNull();
    expect(extrairIp(new Headers({ "x-forwarded-for": "x".repeat(100) }))).toBeNull();
  });
});

describe("hashDoIp", () => {
  it("é estável, depende do sal e não devolve o IP", () => {
    const a = hashDoIp("203.0.113.5", "sal1");
    expect(a).toBe(hashDoIp("203.0.113.5", "sal1"));
    expect(a).not.toBe(hashDoIp("203.0.113.5", "sal2"));
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(a).not.toContain("203");
  });
  it("sem IP ou sem sal não gera hash", () => {
    expect(hashDoIp(null, "sal")).toBeNull();
    expect(hashDoIp("203.0.113.5", "")).toBeNull();
  });
});
