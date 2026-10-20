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
| `0010_duplicidade_por_evento.sql` | Duplicidade de presença por evento (inclui registros antigos), mensagem clara e conferência na portaria | aplicar agora |
| `0011_varios_grupos_por_usuario.sql` | Vários grupos por usuário (as permissões somam), com proteção do último administrador | aplicar agora |
| `0012_hierarquia_organizacional.sql` | Estado > Região > Setor > Comum, vínculos dos usuários e acesso por região (membros, eventos, presenças, portarias) | aplicar agora |
| `0013_excluir_organizacao.sql` | Lixeira na Organização: excluir estado, região, setor ou comum vazios (permissão organizacao.excluir) | aplicar agora |
| `0014_visitantes_portaria.sql` | Cadastro rápido de visitante na portaria (permissão portaria.cadastrar_visitante) e marca de visitante nos membros | aplicar agora |
| `0015_auditoria_e_origem_visitante.sql` | Auditoria automática (gatilhos, logins, impressões), permissão auditoria.visualizar e origem do visitante vinda do banco | aplicar agora |
| `0016_instrumento_obrigatorio.sql` | Instrumento obrigatório para o cargo Músico (banco e telas) e família do instrumento nas opções do visitante | aplicar agora |
| `0017_foto_obrigatoria.sql` | Fotografia obrigatória no cadastro novo (membro e visitante), envio da foto por quem cadastra e troca de foto respeitando a região | aplicar agora |
| `0018_relatorios.sql` | Módulo Relatórios: permissão relatorios.visualizar e consultas (presença, membros, eventos, contagens) respeitando a região | aplicar agora |
| `0019_preferencias_visuais.sql` | Preferências de aparência por usuário (modo claro/escuro, cor principal e tamanho da letra) | aplicar agora |
| `0020_backup.sql` | Backup (base): permissões travadas ao Administrador, tabelas e armazenamento privado do módulo, função de restauração em uma transação | aplicar agora |
| `0021_backup_verificacao.sql` | Verificação automática dos backups: situação (pendente, ok ou falhou), quando, por quem e detalhe | aplicar agora |

Atenção: **não reexecute o `0001` depois do `0002`**. O 0001 recria as políticas antigas, que liberavam
o acesso anônimo. Novas alterações de banco entram sempre como um novo arquivo numerado.

## Migrações 0026 a 0033 (aplicar no Supabase SQL Editor, na ordem, ANTES do git push)

| Arquivo | O que faz |
|---|---|
| `0026_painel_ao_vivo.sql` | Painel ao vivo do evento (linhas, categorias e contagem) |
| `0027_portaria_3h.sql` | A portaria fica aberta de 2h antes até 3h depois do início do evento |
| `0028_portaria_toca_avulsa.sql` | Pergunta "Vai tocar?" e entrada sem cadastro (tabela presencas_avulsas) |
| `0029_instrumento_do_cadastro.sql` | O músico toca só o instrumento do cadastro |
| `0030_portaria_encerrada.sql` | Portaria encerrada não aceita nada (só o Administrador corrige registros) |
| `0031_casa_de_oracao.sql` | Renomeia Comum para Casa de Oração em todo o banco (tabela casas_oracao, coluna casa_oracao_id, nível CASA_ORACAO) |
| `0032_regras_de_regiao.sql` | Corrige regiao_eventos e regiao_membros: restritivas e só para usuários logados |
| `0033_backup_presencas_avulsas.sql` | Entradas sem cadastro entram no backup e na restauração |

## Migração 0034 (aplicar no Supabase SQL Editor ANTES do git push)

| Arquivo | O que faz |
|---|---|
| `0034_ciclo_de_vida_eventos.sql` | Ciclo de vida do evento: cancelar com motivo (só Administrador, permissão eventos.cancelar), evento encerrado vira somente leitura, evento com presenças não pode ser excluído, portaria só para evento aberto |
| `0035_libera_janela_portaria.sql` | Libera para usuários logados as funções que só calculam a janela de horário da portaria (corrige o erro ao editar evento) |

## Migração 0036 (aplicar no Supabase SQL Editor ANTES do git push)

| Arquivo | O que faz |
|---|---|
| `0036_relatorio_presenca_portaria.sql` | Relatório de presença de uma portaria (impressão): evento, resumo e lista de presentes agrupada por linha do painel, com entradas sem cadastro |
