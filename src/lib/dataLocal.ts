/**
 * Sysmusica — Conversão de datas para o campo <input type="datetime-local">.
 *
 * O campo trabalha com texto "AAAA-MM-DDTHH:mm" SEM fuso (hora do navegador), enquanto o banco
 * guarda timestamptz (UTC). Estas funções fazem a ida e a volta sem deslocar o horário.
 */

/** ISO do banco -> valor do campo datetime-local, na hora do navegador. */
export function isoParaDatetimeLocal(iso: string): string {
  const data = new Date(iso);
  const doisDigitos = (numero: number) => String(numero).padStart(2, "0");
  return (
    `${data.getFullYear()}-${doisDigitos(data.getMonth() + 1)}-${doisDigitos(data.getDate())}` +
    `T${doisDigitos(data.getHours())}:${doisDigitos(data.getMinutes())}`
  );
}

/** Valor do campo datetime-local -> ISO (UTC) para gravar no banco; null se for inválido. */
export function datetimeLocalParaIso(valor: string): string | null {
  const data = new Date(valor);
  return Number.isNaN(data.getTime()) ? null : data.toISOString();
}
