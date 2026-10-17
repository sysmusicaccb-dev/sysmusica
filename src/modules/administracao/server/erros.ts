/**
 * SysMúsica — Erro com código HTTP, usado nas rotas de servidor da Administração.
 * A mensagem é escrita para o usuário final (sem detalhes técnicos).
 */
export class ErroHttp extends Error {
  readonly status: number;

  constructor(status: number, mensagem: string) {
    super(mensagem);
    this.status = status;
  }
}
