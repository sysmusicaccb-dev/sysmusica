# Migrações do banco (Supabase)

Aplique **em ordem numérica**, cada arquivo **uma única vez**, no SQL Editor do Supabase
(Dashboard > SQL Editor > colar o arquivo inteiro > Run).

| Arquivo | O que faz | Situação |
|---------|-----------|----------|
| `0001_baseline.sql` | Estrutura inicial (cargos, famílias, instrumentos, membros, eventos, presenças) | já aplicado |
| `0002_rbac.sql` | Usuários, grupos e permissões; RLS por permissão; fim do acesso anônimo | já aplicado |
| `0003_administracao.sql` | Funções para criar/editar grupos, definir permissões e editar usuários pelo sistema | já aplicado |
| `0004_cadastros.sql` | Finalidade do evento, exclusão lógica de membros/eventos e exclusões protegidas | aplicar agora |

Atenção: **não reexecute o `0001` depois do `0002`**. O 0001 recria as políticas antigas, que liberavam
o acesso anônimo. Novas alterações de banco entram sempre como um novo arquivo numerado.
