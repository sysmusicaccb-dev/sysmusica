# Migrações do banco (Supabase)

Aplique **em ordem numérica**, cada arquivo **uma única vez**, no SQL Editor do Supabase
(Dashboard > SQL Editor > colar o arquivo inteiro > Run).

| Arquivo | O que faz | Situação |
|---------|-----------|----------|
| `0001_baseline.sql` | Estrutura inicial (cargos, famílias, instrumentos, membros, eventos, presenças) | já aplicado |
| `0002_rbac.sql` | Usuários, grupos e permissões; RLS por permissão; fim do acesso anônimo | já aplicado |
| `0003_administracao.sql` | Funções para criar/editar grupos, definir permissões e editar usuários pelo sistema | já aplicado |
| `0004_cadastros.sql` | Finalidade do evento, exclusão lógica de membros/eventos e exclusões protegidas | já aplicado |
| `0005_portaria_edicao.sql` | Editar e excluir (lógico) presenças da portaria | já aplicado |
| `0006_identidade_membro.sql` | CPF, cidade/bairro, QR Code (ver e substituir) e auditoria base | já aplicado |
| `0007_portarias.sql` | Portarias: criação, aprovação, cota diária, abrangência por cidade e presença só em portaria aprovada | já aplicado |
| `0008_atendimento_portaria.sql` | Atendimento da portaria: QR Code, busca pelo nome, fotografia do membro (bucket privado) e permissão membros.foto | aplicar agora |
| `0009_controle_total_portarias.sql` | Permissão Controle total de portarias (aprovar a própria, sem limite diário e sem restrição de abrangência) | aplicar agora |

Atenção: **não reexecute o `0001` depois do `0002`**. O 0001 recria as políticas antigas, que liberavam
o acesso anônimo. Novas alterações de banco entram sempre como um novo arquivo numerado.
