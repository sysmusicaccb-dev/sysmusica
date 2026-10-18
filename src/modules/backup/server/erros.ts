/** SysMúsica — Erro do módulo de Backup com o código HTTP que a rota devolve (a mensagem vai para a tela). */
export class ErroBackup extends Error {
  readonly status: number;

  constructor(status: number, mensagem: string) {
    super(mensagem);
    this.name = "ErroBackup";
    this.status = status;
  }
}
