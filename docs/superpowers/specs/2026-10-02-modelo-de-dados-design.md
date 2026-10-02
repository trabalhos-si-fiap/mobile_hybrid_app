# Modelo de Dados (MER, DER e PL/SQL) — Design

Data: 2026-10-02
Sub-projeto 5A de 5 da Fase 6 (FIAP). Depende dos sub-projetos 1 a 4, já em
`main`. Só produz documentação: não mexe em código, migration nem PL/SQL.

## Contexto

A divisão da Fase 6 (spec do sub-projeto 1) reservou o sub-projeto 5 para a
"documentação consolidada e DER". Ele foi dividido em dois:

- **5A, modelo de dados (este documento):** insumos para montar o MER e o
  DER, dicionário de dados e documentação dos objetos PL/SQL. Pode começar
  agora, porque o dashboard (sub-projeto 4), último a mexer no banco, já está
  em `main`.
- **5B, documentação consolidada da entrega:** fica para depois e usa o
  material do 5A.

Estado do banco em `main`:

- 19 tabelas: 6 na `V1` (Edu Admin: `admin_users`, `products`, `inventories`,
  `inventory_adjustments`, `carriers`, `carrier_occurrences`), 9 na `V3`
  (tickets omnichannel: `skills`, `employees`, `employee_skills`,
  `ticket_tipo_config`, `tickets`, `ticket_messages`, `ticket_attachments`,
  `ticket_events`, `notifications`) e 4 na `V5` (chatbot: `chatbot_faq`,
  `chatbot_faq_keywords`, `chatbot_conversations`, `chatbot_messages`).
- 27 FKs e 29 índices explícitos (5 na `V1`, 15 na `V3`, 6 na `V5`, 3 na
  `V8`). A `V3` acrescenta `CK_ADMIN_USERS_ROLE` a `admin_users` com
  `ALTER TABLE`.
- 7 objetos PL/SQL em `db/plsql/`: `FN_PROXIMO_ATENDENTE`,
  `FN_STATUS_SLA_TICKET`, `PR_ROTEAR_TICKET`, `PR_ESCALAR_TICKET_CRITICO`,
  `FN_CHATBOT_RESPOSTA`, `FN_CALC_TAXA_VARIACAO` e `PR_RESUMO_DASHBOARD`.
- Seeds em `db/seed/` (`V2`, `V4`, `V6`, `V7`, `V9`): dados, não esquema. A
  `V3` grava os dados de referência (3 skills e 3 segmentos), sem os quais o
  roteamento não funciona.

A FIAP (`Omnichannel Edu.txt`) sugere 5 tabelas (`Occurrence`,
`Occurrence_Attachment`, `Skill`, `Employee_Skill`, `Occurrence_Message`). O
modelo real cobre essas 5 com outros nomes e acrescenta outras; a
documentação precisa mostrar essa correspondência.

### Decisões tomadas no brainstorming

- O diagrama é montado pelo autor da entrega numa ferramenta, não gerado
  aqui. **DER:** SQL Developer Data Modeler, importando um DDL consolidado.
  **MER conceitual:** brModelo (notação de Chen), montado à mão a partir de
  uma lista de entidades, relacionamentos e cardinalidades.
- O DDL consolidado é escrito à mão, para ser legível, e conferido por um
  script contra as migrations. Gerar com `DBMS_METADATA` foi descartado: a
  saída traz aspas, o nome do schema e cláusulas de sequence e storage em
  cada tabela. A importação pelo dicionário de dados do Oracle de pé fica
  como plano B no guia.
- O DER e o MER cobrem as 19 tabelas, inclusive as 5 do Edu Admin que não se
  ligam ao atendimento.

## Objetivo

Entregar em `docs/banco-de-dados/` tudo o que o autor precisa para montar o
MER no brModelo e o DER no Data Modeler sem ler as migrations, mais o
dicionário de dados e a documentação PL/SQL que acompanham os diagramas na
entrega.

## Fora de escopo

- Migration nova: nada de `COMMENT ON` nem de `V10`.
- Imagem ou PDF dos diagramas, que o autor gera na ferramenta.
- Diagrama em Mermaid ou em outro formato renderizado no repositório.
- O documento consolidado da entrega (sub-projeto 5B).
- Correções no banco. O que aparecer durante o trabalho vai para
  `docs/pendencias.md`.

## Arquivos (`docs/banco-de-dados/`)

Todos em português, seguindo o tom dos documentos existentes.

### `README.md`: guia

- Para que serve cada arquivo da pasta.
- **DER no SQL Developer Data Modeler:**
  1. File > Import > DDL File, banco Oracle Database 23ai (ou a versão mais
     nova que a ferramenta oferecer), e `ddl-consolidado.sql`.
  2. Confirmar que entram as 19 tabelas e as 27 FKs.
  3. Criar três subviews:
     - **Atendimento omnichannel:** `admin_users` e as 9 tabelas da `V3`;
     - **Chatbot:** as 4 tabelas da `V5`, mais `admin_users`,
       `ticket_tipo_config` e `tickets` como contexto;
     - **Edu Admin:** as tabelas da `V1`, exceto `admin_users`.
  4. Opcional: gerar o modelo lógico (Engineer to Logical Model) e exportar
     as imagens.
- **Plano B:** File > Import > Data Dictionary, apontando para o Oracle da
  stack (`localhost:1521/FREEPDB1`, usuário `edu_admin`). Serve se o
  importador de DDL recusar alguma sintaxe, por exemplo o `BOOLEAN` nativo.
  O guia avisa que a stack precisa estar no ar com a `V8` aplicada (a API
  aplica as migrations ao subir).
- **MER no brModelo:** como transpor `mer-conceitual.md` (entidades,
  atributos, identificadores, relacionamentos, cardinalidades, especialização
  e atributo multivalorado).
- **Correspondência com a FIAP:** tabela com as 5 tabelas sugeridas, as
  tabelas reais que as cobrem e a diferença de cada uma. Por exemplo,
  `Occurrence` vira `tickets` (mais prioridade, SLA, atendente e alerta de
  engenharia) e `Occurrence_Message` vira `ticket_messages`. Depois, as
  tabelas que não estavam na sugestão e o motivo de cada uma
  (`ticket_tipo_config`, `ticket_events`, `notifications`, `employees` e as
  do chatbot).
- **Manutenção:** quem criar a `V10` atualiza `ddl-consolidado.sql`, roda
  `conferir-ddl.sh` e revê os outros três documentos.

### `ddl-consolidado.sql`

- `CREATE TABLE` das 19 tabelas e `CREATE INDEX` dos 29 índices explícitos,
  com os mesmos nomes, tipos, padrões, identidades e constraints das
  migrations.
- `CK_ADMIN_USERS_ROLE` entra no próprio `CREATE TABLE admin_users`.
- Sem seed, sem os dados de referência da `V3` e sem PL/SQL.
- Três blocos comentados, na ordem Edu Admin (`V1`), atendimento omnichannel
  (`V3`) e chatbot (`V5`). Os índices ficam no bloco da sua tabela, e os da
  `V8` levam um comentário de origem. As tabelas aparecem numa ordem que
  respeita as FKs: o arquivo roda de uma vez num schema vazio.
- Cabeçalho que diz de onde o arquivo vem (`V1`, `V3`, `V5` e `V8`), que ele
  não substitui as migrations e como conferi-lo.

### `conferir-ddl.sh`

Confere que o DDL consolidado gera o mesmo esquema que as migrations.

- Só precisa de Docker. Sobe um `gvenzl/oracle-free:23-slim-faststart`
  efêmero, a mesma imagem dos testes de integração, sem porta publicada,
  e o remove ao terminar, com sucesso ou não (`trap`).
- Cria dois schemas. No primeiro roda todos os `V*.sql` de
  `api/src/main/resources/db/migration/`, em ordem de versão. A lista é lida
  da pasta, então uma `V10` nova entra sozinha e o script passa a falhar até
  o DDL ser atualizado. No segundo roda `ddl-consolidado.sql`. Qualquer erro
  de SQL encerra o script com falha (`WHENEVER SQLERROR EXIT FAILURE`).
- Compara os dois schemas pelo dicionário do Oracle, nos dois sentidos
  (`MINUS`), e imprime cada diferença:
  - tabelas;
  - colunas: nome, posição, tipo, tamanho (`char_length` e `char_used`),
    precisão, escala, nulidade, padrão, `default_on_null` e identidade
    (`generation_type`);
  - constraints com nome dado (as `NOT NULL` geradas pelo sistema ficam de
    fora, porque a nulidade já é comparada nas colunas): tipo, condição,
    constraint referenciada, regra de exclusão e colunas em ordem;
  - índices: nome, unicidade e colunas em ordem, com o sentido.
- Sai com 0 e uma linha de resumo quando os schemas são iguais, e com 1 e a
  lista de diferenças quando não são.

### `mer-conceitual.md`

Insumo para o brModelo. Fica no nível conceitual: sem tipos, sem índices,
sem chaves estrangeiras e sem colunas técnicas (`updated_at`, `object_key`,
`password`, `misses`).

- **Entidades** com nome em português, a tabela que as implementa,
  identificador e atributos principais. Exemplos: Usuário (`admin_users`),
  Atendente (`employees`), Skill, Segmento (`ticket_tipo_config`), Ticket,
  Mensagem do ticket, Anexo, Evento do ticket, Notificação, Pergunta do FAQ,
  Conversa do chatbot, Mensagem do chatbot, Produto, Estoque, Ajuste de
  estoque, Transportadora e Ocorrência da transportadora.
- **Relacionamentos.** Cada FK vira um relacionamento com nome de verbo e
  cardinalidade (mín, máx) dos dois lados, tirada da nulidade e da unicidade
  das colunas. As exceções:
  - `employees.user_id` vira especialização parcial: Atendente é um Usuário;
  - `employee_skills` vira um relacionamento N:N, "domina", entre Atendente e
    Skill;
  - `chatbot_faq_keywords` vira o atributo multivalorado "palavras-chave" de
    Pergunta do FAQ.

  O resultado são 24 relacionamentos e 1 especialização a partir das 27 FKs.
- **Notas de mapeamento para o DER:**
  - a especialização é implementada numa tabela própria, com `id`
    substituto e `user_id` único;
  - o segmento é uma entidade porque carrega skill, fila, prioridade e SLA;
  - Conversa do chatbot gera no máximo 1 ticket, garantido por
    `UQ_CHATBOT_CONV_TICKET`.
- Os três grupos (atendimento, chatbot e Edu Admin) aparecem separados, como
  as subviews do DER.

### `dicionario-de-dados.md`

- Uma seção por tabela, agrupadas como no DDL. Cada seção traz a finalidade
  em uma ou duas frases e a migration de origem.
- Uma tabela de colunas: nome, tipo, nulo, padrão, chave (PK, FK para quê,
  UQ) e descrição.
- As `CHECK` com os valores aceitos e o significado de cada um: status do
  ticket, presença, tipos de evento, tipos de notificação, estados da
  conversa e as demais.
- Os índices da tabela e o motivo de cada um: índice de FK ou de consulta, e
  qual consulta ou objeto PL/SQL o usa.
- O conteúdo de referência gravado pela `V3`: as 3 skills e a matriz dos 3
  segmentos (skill, fila, prioridade, SLA e escalonamento).

### `plsql.md`

Um resumo no topo (objeto, tipo, papel e chamador) e uma seção por objeto,
com:

- a assinatura exata, copiada do `R__`;
- os parâmetros, e o retorno ou os cursores de saída com suas colunas;
- a regra em passos curtos;
- as tabelas lidas e as gravadas;
- as travas e a transação: `FOR UPDATE`, savepoints, e o fato de nenhum
  objeto fazer `COMMIT`;
- os erros levantados (`RAISE_APPLICATION_ERROR` e código) e como a API os
  traduz;
- quem chama: a classe Java e o endpoint ou o job;
- os testes que cobrem o objeto.

Fecha com um diagrama em texto de quem chama quem, no estilo do fluxo de
`api/ARCHITECTURE.md`.

## Mudanças em documentos existentes

- `README.md` (raiz): link para `docs/banco-de-dados/` na seção de
  documentação.
- `api/ARCHITECTURE.md`:
  - na seção "Banco de dados", um link para `docs/banco-de-dados/`;
  - na tabela de PL/SQL, a linha de `FN_CHATBOT_RESPOSTA`, que falta;
  - "Domínios persistidos" passa a listar também os grupos de tickets e do
    chatbot.
- `docs/pendencias.md`: seção "Sub-projeto 5A", preenchida na revisão final.

## Ambiente de trabalho

- Worktree `../mobile_hybrid_app-modelo-dados`, branch
  `docs/modelo-de-dados`, criado de `main` depois do merge do dashboard.
- Nenhuma stack é usada. `conferir-ddl.sh` sobe e remove o próprio Oracle. A
  stack de demonstração (`edu-admin-*`) não é tocada.

## Critérios de pronto

- `conferir-ddl.sh` sai com 0.
- `conferir-ddl.sh` sai com 1 e aponta a diferença numa cópia do DDL com um
  índice removido e uma coluna com tamanho trocado. A cópia é descartada:
  esse teste é só do trabalho e não fica no repositório.
- Toda tabela, coluna, constraint e índice citado nos quatro documentos
  existe no DDL, conferido por script durante o trabalho.
- O dicionário cobre as 19 tabelas e todas as colunas, e a contagem bate com
  o dicionário do Oracle do schema consolidado.
- As assinaturas em `plsql.md` batem com os `R__`.
- Smoke manual, feito pelo autor: importar o DDL no Data Modeler (19
  tabelas, 27 FKs) e montar o MER no brModelo a partir de
  `mer-conceitual.md`. O que falhar volta como correção no guia ou no DDL.

## Riscos

- **Importador do Data Modeler.** Versões antigas podem não aceitar o
  `BOOLEAN` nativo do 23ai ou `GENERATED BY DEFAULT ON NULL AS IDENTITY`. O
  plano B (dicionário de dados) contorna isso sem mudar o DDL. Se nem ele
  servir, o guia diz como trocar o tipo na ferramenta.
- **Desatualização.** Uma migration nova sem atualização do DDL faz o
  `conferir-ddl.sh` falhar, mas só quando alguém o roda. O guia e o
  `ARCHITECTURE.md` mandam rodá-lo ao criar migration.
- **Diferença entre o sqlplus e o Flyway.** O script roda as migrations pelo
  sqlplus, não pelo Flyway. Isso funciona porque os `V__` de `migration/`
  são DDL e `INSERT` simples, sem bloco PL/SQL. Se um dia houver bloco, o
  script precisa tratar o `/`.
