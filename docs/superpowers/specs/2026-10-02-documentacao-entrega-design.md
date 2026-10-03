# Documentação da Entrega (Atividade Case Fase 6) — Design

Data: 2026-10-02
Sub-projeto 5B de 5 da Fase 6 (FIAP). Depende de tudo o que já está em
`main`: sub-projetos 1 a 4, o 5A (modelo de dados) e o primeiro bloco de
correções das pendências (`fix/pendencias-bloco-1`).

## Contexto

O enunciado da FIAP pede, num .ZIP entregue na plataforma ON:

1. a documentação em PDF, gerada de um editor de texto (Word), respondendo às
   Partes 1 a 3 da atividade;
2. o código ou o link do GitHub;
3. slides em PDF (até 10, com o grupo no início);
4. o link de um vídeo de até 5 minutos, com o app rodando.

O grupo já tem o modelo do documento: `docs/atividade_case_fase_6.docx`, fora
do git. Ele traz a capa (nomes, RMs e turma), o título "Atividade Case —
Fase 6", o link do repositório e as seções das Partes 1 a 3, com o texto do
enunciado e, no lugar do conteúdo, instruções destacadas em amarelo:

| # | Seção | Instrução em amarelo |
|---|---|---|
| 1 | Cabeçalho | "Link do vídeo:" vazio |
| 2 | Parte 1 | "Descrever refatorações e novas funcionalidades desenvolvidas e documentar valor agregado." |
| 3 | Parte 1 — Evidências de desenvolvimento e Cumprimento de Requisitos | "adicionar imagens de evidências como trechos de código, print de novas telas, etc." |
| 4 | Parte 2 — Modelo lógico/físico do Banco de Dados Oracle | "Breve explicação e adicionar imagem de diagrama MER" |
| 5 | Parte 2 — Implementação das tabelas em ambiente Oracle — Scripts | "Breve explicação e imagens dos scripts utilizados" |
| 6 | Parte 2 — Importação de dados de usuários e histórico realizadas | "Breve explicação de quais dados importamos, de qual banco de dados e imagens de evidência" |
| 7 | Parte 2 — Diagrama Entidade Relacionamento — DER | "Imagem do diagrama realizado na ferramenta Oracle" |
| 8 | Parte 3 | "Breve explicação de propósito e funcionamento de cada procedure, com funções que calcule algum indicador importante e que retorne dados formatados relevantes, utilização de boas práticas — tratamento de exceções, comentários, parâmetros IN e RETURN, e integrar as consultas SQL" |
| 9 | Parte 3 — Evidências de desenvolvimento | "Adicionar imagens de cada procedure criada" |

O enunciado fala em "Smart HAS" (texto genérico da FIAP); o projeto é o Edu,
e o documento liga cada item pedido ao que existe aqui.

### Decisões tomadas no brainstorming

- Este sub-projeto preenche o modelo do grupo; slides, roteiro do vídeo e o
  .ZIP ficam fora.
- Todas as imagens possíveis são produzidas aqui: código, execução no
  Oracle, prints do console web e prints do app no aparelho Android
  conectado. MER e DER saem das ferramentas (brModelo e Data Modeler, ver
  P5A-01) e ficam como espaços marcados.
- O resultado é um arquivo novo, `docs/atividade_case_fase_6_preenchido.docx`;
  o modelo fica intacto. Os dois `.docx` ficam fora do git.
- Entra um script de consultas de exemplo no repositório, que é o "integrar
  as funções a consultas SQL e mostrar seus usos práticos" da Parte 3.

## Objetivo

Entregar o documento da atividade com todas as lacunas preenchidas, exceto o
link do vídeo, a imagem do MER e a do DER, que dependem do grupo, pronto
para abrir no Word, completar esses três pontos e exportar o PDF.

## Fora de escopo

- Slides, roteiro do vídeo, gravação e montagem do .ZIP.
- Mudanças de código, migrations, PL/SQL, `README.md`, `openapi.yaml` ou
  `docs/pendencias.md`.
- Imagens de MER e DER (ferramentas do grupo).
- Reescrever o texto do enunciado que já está no modelo.

## Componentes

### 1. Stack de evidências

Uma stack isolada, subida da `main` só para gerar as evidências, com o seed
completo de demonstração (migrations, `V2` a `V9` e PL/SQL), para que SQL,
console e app mostrem os mesmos dados.

- `COMPOSE_PROJECT_NAME=edu-evidencias` e um override no scratchpad que
  troca os `container_name` (`edu-evid-*`) e as portas: Oracle 12521, MinIO
  19100/19101, API 18180, web 14300. O web chega à API pela rede do Compose,
  como na stack de demonstração.
- Sobe do zero, logo antes das capturas: o seed `V9` é relativo à hora da
  migration, e o pico do dashboard só aparece nas 24 horas seguintes.
- No fim, `docker compose ... down -v` só desse projeto. A stack de
  demonstração (`edu-admin-*`) não é tocada.

### 2. Consultas de exemplo (no repositório)

- `docs/banco-de-dados/consultas-exemplo.sql`: script para o sqlplus, com
  comentários, que mostra cada objeto em uso:
  - `FN_STATUS_SLA_TICKET` na listagem dos tickets em aberto e numa
    contagem por status de SLA;
  - `FN_CALC_TAXA_VARIACAO` comparando o volume de cada segmento entre os
    últimos 7 dias e os 7 anteriores;
  - `FN_PROXIMO_ATENDENTE` mostrando quem receberia o próximo ticket de cada
    skill (com a stack recém-subida, todos `OFFLINE`; o script põe um
    atendente `ONLINE` numa transação e desfaz no fim);
  - `FN_CHATBOT_RESPOSTA` com frases de exemplo e a pergunta do FAQ
    escolhida;
  - `PR_RESUMO_DASHBOARD` imprimindo os três cursores (`VARIABLE ...
    REFCURSOR` e `PRINT`);
  - `PR_ROTEAR_TICKET` e `PR_ESCALAR_TICKET_CRITICO` executados sobre
    tickets do seed, mostrando eventos e notificações gerados, e desfeitos
    com `ROLLBACK`.
- `docs/banco-de-dados/consultas-exemplo.saida.txt`: a saída real, rodada no
  Oracle da stack de evidências.
- O cabeçalho do script diz como rodá-lo (`docker exec -i <oracle> sqlplus
  ... < consultas-exemplo.sql`) e que ele não deixa alterações no banco.

### 3. Imagens

Geradas por scripts descartáveis no scratchpad, em PNG, com largura que cabe
na página do modelo (A4, margens do modelo).

- **Código:** trechos renderizados no Chromium headless do Playwright (o
  mesmo do e2e web), com fonte monoespaçada, fundo claro e o caminho do
  arquivo no topo. Fonte: os arquivos reais do repositório, por intervalo de
  linhas, nunca redigitados.
- **Execução no Oracle:** blocos da saída do item 2 e uma consulta de
  contagem de linhas por tabela, renderizados do mesmo jeito.
- **Console web:** Playwright contra a stack de evidências, com as contas do
  seed. Fila do atendimento, console de um ticket com a conversa e a
  transcrição do chatbot, dashboard do atendimento com o pico do seed.
- **App Flutter:** APK de debug gerado pelo serviço `flutter` do Compose,
  com `API_BASE_URL` apontando para a API da stack de evidências por
  `adb reverse`, instalado no aparelho conectado. Telas: login, Mentor Edu
  (conversa com o bot), formulário de ticket preenchido pela passagem, Meus
  tickets e a conversa de um ticket. Captura com `adb exec-out screencap`;
  navegação por `adb shell input` com as posições tiradas do `uiautomator
  dump`. O aparelho precisa estar desbloqueado; o build de debug substitui o
  app instalado, como no e2e.

### 4. Preenchimento do `.docx`

Script descartável que copia o modelo, edita `word/document.xml` e acrescenta
as imagens (`word/media/`, relações e tipo de conteúdo PNG), sem
reformatar o resto do XML.

- Cada parágrafo amarelo vira o conteúdo da seção, nos estilos que o modelo
  já usa (texto normal, listas com a numeração do modelo, subtítulos no
  nível dos existentes), sem destaque.
- Imagens centralizadas, com legenda "Figura N — ..." numerada em ordem.
- Tabelas com bordas simples e largura da página.
- Ficam em amarelo, de propósito, só três marcações: o link do vídeo, o
  espaço da imagem do MER e o do DER, cada uma dizendo o que colar e de onde
  (o guia `docs/banco-de-dados/README.md`).

Conteúdo por seção:

- **Parte 1 (texto):** o que a Fase 6 acrescentou ao Edu (tickets
  omnichannel com roteamento por skill, console de atendimento, app do
  usuário, chatbot nível 0, dashboard do atendimento, base Oracle);
  refatorações (H2/PostgreSQL → Oracle com Flyway, Java só em container,
  pirâmide de testes com Oracle efêmero, autorização por papéis, correções
  do bloco 1 de pendências); valor agregado; tabela com os requisitos do
  "Omnichannel Edu" e como cada um foi atendido; a justificativa de o
  chatbot ser um bot de regras deste repositório e não o `/api/v1/chat` do
  `edu-ia`.
- **Parte 1 (evidências):** prints do console web e do app, e um trecho de
  código representativo de cada camada.
- **Parte 2:** modelo lógico/físico em resumo (19 tabelas em três grupos,
  convenções de nomes, tipos do 23ai) e o espaço do MER; os scripts Flyway
  (`migration/`, `seed/`, `plsql/`) com imagens de trechos; os dados
  simulados (o que cada seed carrega, que os dados do Edu Admin vieram do
  antigo `DataSeeder` em PostgreSQL e foram reescritos como SQL Oracle) com
  a contagem por tabela como evidência; o espaço do DER.
- **Parte 3:** uma tabela ligando cada exigência da FIAP ao objeto que a
  atende (indicador: `FN_CALC_TAXA_VARIACAO`; dados formatados:
  `FN_STATUS_SLA_TICKET`; procedures; a acionada por Java:
  `PR_ROTEAR_TICKET` via `POST /tickets`; EXCEPTION, IF, LOOP e CURSOR);
  propósito e funcionamento de cada um dos 7 objetos, condensados do
  `docs/banco-de-dados/plsql.md`; as boas práticas presentes em cada
  function; o uso em consultas, com as saídas do item 2; a cadeia REST →
  serviço → `CallableStatement` → Oracle.
- **Parte 3 (evidências):** para cada procedure e function, a imagem do
  código e a da execução.
- **Seção final "Limitações conhecidas":** 8 a 10 itens ainda abertos de
  `docs/pendencias.md`, em linguagem de usuário, apontando para a lista
  completa no repositório.

## Ambiente de trabalho

- Worktree `../mobile_hybrid_app-entrega`, branch `docs/documentacao-entrega`,
  para o script de consultas, a saída, esta spec e o plano.
- O modelo é lido de `docs/atividade_case_fase_6.docx` na cópia principal
  (`../mobile_hybrid_app`), e o resultado é gravado ao lado dele, fora do
  git.
- Scripts de imagem e de preenchimento ficam no scratchpad.

## Critérios de pronto

- `consultas-exemplo.sql` roda sem erro no Oracle da stack de evidências e
  não deixa alteração (contagens de tickets, eventos e notificações iguais
  antes e depois).
- O `.docx` preenchido passa no `validate.py` do skill de docx contra o
  modelo e abre no LibreOffice; o PDF renderizado é conferido página a
  página (texto, tabelas, imagens legíveis, figuras numeradas em ordem).
- Nenhuma instrução amarela do modelo sobra, exceto as três marcações
  intencionais.
- Todo nome de tabela, constraint, índice e objeto PL/SQL citado existe
  (conferidor do 5A, aplicado ao texto extraído do `.docx`).
- A stack de evidências foi removida (`down -v`), a de demonstração segue
  como estava, e nenhum container `edu-evid-*` sobra.

## Riscos

- **Aparelho bloqueado ou ocupado.** Sem o aparelho, os prints do app viram
  espaços marcados e o resto segue.
- **Navegação por coordenadas no app.** Frágil se o layout mudar; as
  posições saem do `uiautomator dump` na hora, e cada print é conferido
  visualmente.
- **Primeira subida lenta.** Compilar a API e o APK leva minutos; os caches
  do Compose já existem na máquina.
- **Formatação do modelo.** Editar o XML à mão pode quebrar estilos; o
  validador e a renderização em PDF pegam isso antes da entrega.
