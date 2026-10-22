import { describe, expect, it } from "vitest";
import {
  classeIconeVerificacao,
  compararContagens,
  descreverEtiquetaVerificacao,
  mensagemVerificacaoFalhou,
  mensagemVerificacaoManual,
  resumoCurtoVerificacao,
  contarLinhas,
  dataHoraSalvador,
  descreverAvisos,
  descreverVerificacao,
  emailValido,
  empacotarBackup,
  extrairToken,
  formatarTamanho,
  gruposEfetivos,
  idValido,
  lerConfigResend,
  lerConfigSmtp,
  lerPacote,
  mensagemFalha,
  mensagemSucesso,
  nomeDoArquivoBackup,
  totalDeLinhas,
} from "@/modules/backup/regras";

describe("empacotarBackup e lerPacote", () => {
  const tabelas = { membros: [{ id: "m1", nome: "Ana" }], eventos: [] };

  it("guarda e devolve o mesmo conteúdo", () => {
    const pacote = lerPacote(empacotarBackup(tabelas, new Date("2026-10-18T15:30:00Z")));
    expect(pacote.tabelas).toEqual(tabelas);
    expect(pacote.criado_em).toBe("2026-10-18T15:30:00.000Z");
  });

  it("recusa conteúdo corrompido ou de outro tipo", () => {
    expect(() => lerPacote("{quebrado")).toThrow(/corrompido/);
    expect(() => lerPacote("7")).toThrow(/corrompido/);
    expect(() => lerPacote("[]")).toThrow(/corrompido/);
    expect(() => lerPacote(JSON.stringify({ formato: "outro" }))).toThrow(/não é um backup/);
  });

  it("recusa backup de versão mais nova e tabela que não é lista", () => {
    const base = { formato: "sysmusica-backup", criado_em: "x", tabelas: {} };
    expect(() => lerPacote(JSON.stringify({ ...base, versao: 99 }))).toThrow(/versão mais nova/);
    expect(() => lerPacote(JSON.stringify({ ...base, versao: 1, tabelas: { membros: 3 } }))).toThrow(/membros/);
    expect(() => lerPacote(JSON.stringify({ ...base, versao: 1, tabelas: [] }))).toThrow(/corrompido/);
  });
});

describe("contagens", () => {
  it("conta e soma as linhas", () => {
    const contagens = contarLinhas({ a: [{}, {}], b: [{}] });
    expect(contagens).toEqual({ a: 2, b: 1 });
    expect(totalDeLinhas(contagens)).toBe(3);
    expect(totalDeLinhas(null)).toBe(0);
  });

  it("compara exatamente", () => {
    expect(compararContagens({ a: 2 }, { a: 2 })).toBe(true);
    expect(compararContagens({ a: 2 }, { a: 3 })).toBe(false);
    expect(compararContagens({ a: 2 }, { a: 2, b: 1 })).toBe(false);
    expect(compararContagens({ a: 2 }, null)).toBe(false);
  });
});

describe("nomes e formatos", () => {
  it("monta o caminho do arquivo e limpa o sufixo", () => {
    expect(nomeDoArquivoBackup("manual", new Date("2026-10-18T15:30:05Z"), "ab12cd")).toBe(
      "2026/10/backup-20261018-153005-manual-ab12cd.sysbk"
    );
    expect(nomeDoArquivoBackup("diario", new Date("2026-01-02T03:04:05Z"), "AB-12!")).toBe(
      "2026/01/backup-20260102-030405-diario-ab12.sysbk"
    );
    expect(nomeDoArquivoBackup("diario", new Date("2026-01-02T03:04:05Z"), "!!")).toContain("-diario-x.sysbk");
  });

  it("formata o tamanho", () => {
    expect(formatarTamanho(0)).toBe("0 B");
    expect(formatarTamanho(1536)).toBe("1,5 KB");
    expect(formatarTamanho(2.5 * 1024 * 1024)).toBe("2,5 MB");
    expect(formatarTamanho(null)).toBe("—");
  });

  it("mostra a hora de Salvador", () => {
    expect(dataHoraSalvador(new Date("2026-10-18T15:30:00Z"))).toBe("18/10/2026 12:30");
  });
});

describe("mensagens de aviso", () => {
  const quando = new Date("2026-10-18T15:30:00Z");

  it("sucesso traz tipo, data, tamanho e quantidades", () => {
    const { assunto, texto } = mensagemSucesso({
      tipo: "manual",
      quando,
      tamanhoBytes: 2048,
      totalRegistros: 1234,
      totalTabelas: 18,
      feitoPor: "Levi",
    });
    expect(assunto).toBe("Sysmusica: backup concluído");
    expect(texto).toContain("Tipo: Manual");
    expect(texto).toContain("Data: 18/10/2026 12:30");
    expect(texto).toContain("Tamanho: 2,0 KB");
    expect(texto).toContain("Registros: 1.234 em 18 tabelas");
    expect(texto).toContain("Feito por: Levi");
  });

  it("falha traz o motivo, limitado a 300 caracteres", () => {
    const { texto } = mensagemFalha({ tipo: "diario", quando, motivo: "x".repeat(500) });
    expect(texto).toContain("O backup FALHOU.");
    expect(texto.split("Motivo: ")[1].split("\n")[0].length).toBe(300);
    expect(texto).toContain("Tentativa de: sistema");
  });

  it("resume os avisos por canal", () => {
    expect(descreverAvisos([])).toMatch(/Nenhum aviso/);
    expect(
      descreverAvisos([
        { canal: "telegram", estado: "enviado" },
        { canal: "email", estado: "erro", detalhe: "senha recusada" },
      ])
    ).toBe("Telegram: enviado · E-mail: erro (senha recusada)");
  });
});

describe("descreverVerificacao", () => {
  const ok = { ok: true, hashConfere: true, abre: true, contagensConferem: true, totalRegistros: 1234 };

  it("diz que está íntegro", () => {
    expect(descreverVerificacao(ok)).toContain("íntegro");
    expect(descreverVerificacao(ok)).toContain("1.234");
  });

  it("lista os problemas", () => {
    expect(descreverVerificacao({ ...ok, ok: false, hashConfere: false })).toMatch(/impressão digital/);
    expect(descreverVerificacao({ ...ok, ok: false, abre: false, detalhe: "chave errada" })).toMatch(/não abre \(chave errada\)/);
    expect(descreverVerificacao({ ...ok, ok: false, contagensConferem: false })).toMatch(/quantidade de registros/);
  });
});

describe("verificação automática", () => {
  const ok = { ok: true, hashConfere: true, abre: true, contagensConferem: true, totalRegistros: 192 };
  const quando = new Date("2026-10-18T15:30:00Z");

  it("o aviso de sucesso informa a verificação e quando a cópia foi refeita", () => {
    const { texto } = mensagemSucesso({ tipo: "diario", quando, verificacao: ok, refeito: true });
    expect(texto).toContain("Verificação automática: íntegra (192 registros conferidos");
    expect(texto).toContain("refeita automaticamente");
    expect(mensagemSucesso({ tipo: "diario", quando }).texto).not.toContain("Verificação automática");
  });

  it("o resumo curto mostra íntegra ou o problema", () => {
    expect(resumoCurtoVerificacao(ok)).toMatch(/^íntegra/);
    expect(resumoCurtoVerificacao({ ...ok, ok: false, hashConfere: false })).toMatch(/impressão digital/);
  });

  it("explica quando a verificação nem chegou a ser feita", () => {
    const semArquivo = { ...ok, ok: false, abre: false, hashConfere: false, contagensConferem: false, impedimento: "A chave não está configurada." };
    expect(descreverVerificacao(semArquivo)).toBe("Não foi possível verificar: A chave não está configurada.");
  });

  it("o alerta de falha traz o problema e o que fazer", () => {
    const { assunto, texto } = mensagemVerificacaoFalhou({
      tipo: "diario",
      quando,
      verificacao: { ...ok, ok: false, hashConfere: false },
    });
    expect(assunto).toContain("ALERTA");
    expect(texto).toContain("impressão digital");
    expect(texto).toContain("faça um novo backup");
  });

  it("o aviso da verificação manual muda conforme o resultado", () => {
    const bom = mensagemVerificacaoManual({ tipo: "manual", criadoEm: quando, quando, verificacao: ok, feitoPor: "Levi" });
    expect(bom.assunto).toBe("Sysmusica: backup verificado");
    expect(bom.texto).toContain("Verificado por: Levi");
    const ruim = mensagemVerificacaoManual({ tipo: "manual", criadoEm: quando, quando, verificacao: { ...ok, ok: false, abre: false } });
    expect(ruim.assunto).toContain("ALERTA");
    expect(ruim.texto).toContain("Verificado por: sistema");
  });

  it("a etiqueta muda de texto e de cor conforme a situação", () => {
    const base = { verificado_em: null, verificado_por_nome: null, verificacao_detalhe: null };
    expect(descreverEtiquetaVerificacao({ ...base, verificacao: "pendente" })).toMatchObject({
      texto: "A verificar",
      classe: "bg-rose-50 text-rose-600",
    });
    expect(
      descreverEtiquetaVerificacao({ ...base, verificacao: "ok", verificado_em: "2026-10-18T15:30:00Z" })
    ).toMatchObject({ texto: "Verificado", classe: "bg-emerald-50 text-emerald-600", dica: "Verificado pelo sistema em 18/10/2026 12:30." });
    expect(
      descreverEtiquetaVerificacao({ ...base, verificacao: "ok", verificado_em: "2026-10-18T15:30:00Z", verificado_por_nome: "Levi" }).dica
    ).toBe("Verificado por Levi em 18/10/2026 12:30.");
    expect(descreverEtiquetaVerificacao({ ...base, verificacao: "falhou", verificacao_detalhe: "o arquivo não abre" })).toMatchObject({
      texto: "Falha na verificação",
      dica: "o arquivo não abre",
    });
  });

  it("o ícone do botão acompanha a situação", () => {
    expect(classeIconeVerificacao("pendente")).toBe("text-rose-400");
    expect(classeIconeVerificacao("ok")).toBe("text-emerald-500");
    expect(classeIconeVerificacao("falhou")).toBe("text-red-500");
  });
});

describe("validações", () => {
  it("confere e-mails", () => {
    expect(emailValido(" ana@exemplo.com.br ")).toBe(true);
    expect(emailValido("ana@exemplo")).toBe(false);
    expect(emailValido("ana exemplo@x.com")).toBe(false);
    expect(emailValido("")).toBe(false);
  });

  it("lê a configuração de SMTP e recusa a incompleta", () => {
    const completa = { host: " smtp.exemplo.com ", porta: "587", seguro: false, usuario: "u", senha: "s", remetente: "backup@exemplo.com" };
    expect(lerConfigSmtp(completa)).toEqual({
      host: "smtp.exemplo.com",
      porta: 587,
      seguro: false,
      usuario: "u",
      senha: "s",
      remetente: "backup@exemplo.com",
    });
    expect(lerConfigSmtp({ ...completa, host: "" })).toBeNull();
    expect(lerConfigSmtp({ ...completa, porta: 0 })).toBeNull();
    expect(lerConfigSmtp({ ...completa, remetente: "sem-arroba" })).toBeNull();
    expect(lerConfigSmtp(null)).toBeNull();
  });

  it("lê a configuração do Resend e recusa a incompleta", () => {
    expect(lerConfigResend({ chave: "re_123", remetente: "a@b.com" })).toEqual({ chave: "re_123", remetente: "a@b.com" });
    expect(lerConfigResend({ chave: "", remetente: "a@b.com" })).toBeNull();
    expect(lerConfigResend("texto")).toBeNull();
  });

  it("extrai o token do cabeçalho", () => {
    expect(extrairToken("Bearer abc.def")).toBe("abc.def");
    expect(extrairToken("bearer   xyz")).toBe("xyz");
    expect(extrairToken("Basic abc")).toBeNull();
    expect(extrairToken("Bearer a b")).toBeNull();
    expect(extrairToken(null)).toBeNull();
  });

  it("confere identificadores e junta os grupos do usuário", () => {
    expect(idValido("0f8fad5b-d9cb-469f-a165-70867728950e")).toBe(true);
    expect(idValido("../etc/passwd")).toBe(false);
    expect(gruposEfetivos("g1", ["g2", "g1", ""])).toEqual(["g1", "g2"]);
    expect(gruposEfetivos(null, [])).toEqual([]);
  });
});
