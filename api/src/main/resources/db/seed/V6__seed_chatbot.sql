-- Demonstração do chatbot nível 0 (não roda no perfil de teste): o FAQ do
-- Mentor Edu e um ticket aberto por ele, com a conversa ligada.
-- Só INSERTs simples: os R__ (PL/SQL) rodam depois das versões, então o seed
-- não pode depender deles.

-- FAQ: 4 dúvidas por segmento, na ordem em que o bot as oferece.
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('PROBLEMA_PEDIDO', 'Qual o prazo de entrega do meu pedido?',
        'O prazo aparece no resumo do pedido, em Meus pedidos, e começa a contar depois da confirmação do pagamento. '
        || 'Na maioria das regiões a entrega leva de 3 a 7 dias úteis. Se o prazo já passou, fale com um atendente.', 1);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('PROBLEMA_PEDIDO', 'Como faço trocas e devoluções?',
        'Você tem até 7 dias depois do recebimento para pedir a troca ou a devolução, com o produto sem uso e na '
        || 'embalagem original. O reembolso volta pela mesma forma de pagamento em até 10 dias úteis depois que o '
        || 'produto chega ao nosso centro.', 2);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('PROBLEMA_PEDIDO', 'Como rastrear o meu pedido?',
        'Em Meus pedidos, toque no pedido e depois em Rastrear. O código de rastreio também vai por e-mail quando a '
        || 'transportadora coleta o pacote; ele pode levar até 1 dia útil para aparecer.', 3);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('PROBLEMA_PEDIDO', 'Meu pedido veio com item faltando ou errado. E agora?',
        'Sentimos muito! Tire fotos da embalagem e dos itens recebidos e abra um ticket com elas: a equipe de '
        || 'entregas confere com a transportadora e envia o item certo ou faz o reembolso.', 4);

INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('DEFEITO_APP', 'Não consigo entrar no app. O que faço?',
        'Confira se o e-mail está certo e use "Esqueci minha senha" na tela de login para criar uma nova. Se aparecer '
        || 'erro de conexão, verifique a internet e tente de novo em alguns minutos.', 1);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('DEFEITO_APP', 'Não recebo notificações. Como resolver?',
        'Nas configurações do celular, abra Apps > Edu > Notificações e deixe as notificações ativadas. As '
        || 'notificações só chegam para a conta conectada no app.', 2);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('DEFEITO_APP', 'A câmera ou o anexo não funciona. O que fazer?',
        'Permita o acesso à câmera e aos arquivos em Configurações > Apps > Edu > Permissões. Os anexos aceitam PNG, '
        || 'JPEG, WEBP ou PDF de até 5 MB cada.', 3);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('DEFEITO_APP', 'Como atualizar o app?',
        'Abra a Play Store (Android) ou a App Store (iPhone), procure por Edu e toque em Atualizar. A versão mais '
        || 'recente corrige as falhas já conhecidas.', 4);

INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('FEEDBACK_SUGESTAO', 'Como enviar uma sugestão?',
        'Adoramos ideias! Toque em "Falar com atendente", confira o segmento Feedback / Sugestões no formulário e '
        || 'descreva a sua ideia. Ela vai direto para a equipe de produto.', 1);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('FEEDBACK_SUGESTAO', 'Onde acompanho o que sugeri?',
        'Cada sugestão vira um ticket em Meus tickets. Lá você vê o andamento e as respostas da equipe de produto.', 2);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('FEEDBACK_SUGESTAO', 'A equipe responde as sugestões?',
        'Sim. A equipe de produto lê todas as sugestões e responde no próprio ticket em até 2 dias úteis. As ideias '
        || 'aprovadas entram no planejamento das próximas versões.', 3);
INSERT INTO chatbot_faq (segment, question, answer, sort_order)
VALUES ('FEEDBACK_SUGESTAO', 'Como avaliar o app?',
        'Na Play Store ou na App Store, abra a página do Edu e toque nas estrelas. A sua avaliação ajuda outros '
        || 'estudantes a conhecer o app.', 4);

-- Palavras-chave: radicais sem acento, específicos o bastante para palavras
-- comuns ("app", "nao", "pedido") não casarem com tudo.
INSERT INTO chatbot_faq_keywords (faq_id, keyword)
SELECT f.id, k.keyword
  FROM chatbot_faq f
  JOIN (VALUES ('PROBLEMA_PEDIDO', 1, 'prazo'), ('PROBLEMA_PEDIDO', 1, 'entreg'),
               ('PROBLEMA_PEDIDO', 1, 'demor'), ('PROBLEMA_PEDIDO', 1, 'atras'),
               ('PROBLEMA_PEDIDO', 2, 'troc'), ('PROBLEMA_PEDIDO', 2, 'devol'),
               ('PROBLEMA_PEDIDO', 2, 'reembols'), ('PROBLEMA_PEDIDO', 2, 'estorn'),
               ('PROBLEMA_PEDIDO', 2, 'arrepend'), ('PROBLEMA_PEDIDO', 2, 'dinheir'),
               ('PROBLEMA_PEDIDO', 3, 'rastre'), ('PROBLEMA_PEDIDO', 3, 'transportador'),
               ('PROBLEMA_PEDIDO', 3, 'localiz'), ('PROBLEMA_PEDIDO', 3, 'extravi'),
               ('PROBLEMA_PEDIDO', 4, 'faltand'), ('PROBLEMA_PEDIDO', 4, 'faltou'),
               ('PROBLEMA_PEDIDO', 4, 'errad'), ('PROBLEMA_PEDIDO', 4, 'incomplet'),
               ('DEFEITO_APP', 1, 'login'), ('DEFEITO_APP', 1, 'senha'), ('DEFEITO_APP', 1, 'entrar'),
               ('DEFEITO_APP', 1, 'logar'), ('DEFEITO_APP', 1, 'acess'), ('DEFEITO_APP', 1, 'abre'),
               ('DEFEITO_APP', 2, 'notific'), ('DEFEITO_APP', 2, 'aviso'), ('DEFEITO_APP', 2, 'alerta'),
               ('DEFEITO_APP', 3, 'camera'), ('DEFEITO_APP', 3, 'anex'), ('DEFEITO_APP', 3, 'foto'),
               ('DEFEITO_APP', 3, 'arquivo'), ('DEFEITO_APP', 3, 'upload'),
               ('DEFEITO_APP', 4, 'atualiz'), ('DEFEITO_APP', 4, 'versao'), ('DEFEITO_APP', 4, 'instal'),
               ('FEEDBACK_SUGESTAO', 1, 'sugest'), ('FEEDBACK_SUGESTAO', 1, 'suger'),
               ('FEEDBACK_SUGESTAO', 1, 'ideia'), ('FEEDBACK_SUGESTAO', 1, 'melhori'),
               ('FEEDBACK_SUGESTAO', 2, 'acompanh'), ('FEEDBACK_SUGESTAO', 2, 'andament'),
               ('FEEDBACK_SUGESTAO', 2, 'sugeri'), ('FEEDBACK_SUGESTAO', 2, 'sugest'),
               ('FEEDBACK_SUGESTAO', 3, 'respond'), ('FEEDBACK_SUGESTAO', 3, 'respost'),
               ('FEEDBACK_SUGESTAO', 3, 'sugest'),
               ('FEEDBACK_SUGESTAO', 4, 'avali'), ('FEEDBACK_SUGESTAO', 4, 'estrel'),
               ('FEEDBACK_SUGESTAO', 4, 'opini')) k (segment, sort_order, keyword)
    ON k.segment = f.segment AND k.sort_order = f.sort_order;

-- Ticket aberto pelo bot: o usuário escolheu o segmento, digitou a dúvida, a
-- resposta do FAQ não resolveu e ele foi para o formulário. Ninguém da skill
-- estava online, então está na fila sem dono, como o PR_ROTEAR_TICKET deixaria;
-- é roteado quando logistica@edu.com fica ONLINE.
INSERT INTO tickets (user_id, segment, description, channel, status, priority,
                     sla_started_at, sla_due_at, created_at, updated_at)
SELECT id, 'PROBLEMA_PEDIDO', 'Meu pedido chegou incompleto: faltou o carregador.', 'CHATBOT_IA', 'EM_FILA', 'NORMAL',
       SYSTIMESTAMP - NUMTODSINTERVAL(20, 'MINUTE'), SYSTIMESTAMP + NUMTODSINTERVAL(460, 'MINUTE'),
       SYSTIMESTAMP - NUMTODSINTERVAL(20, 'MINUTE'), SYSTIMESTAMP - NUMTODSINTERVAL(20, 'MINUTE')
  FROM admin_users
 WHERE email = 'usuario@edu.com';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, created_at)
SELECT id, 'ABERTO', NULL, 'ABERTO', created_at
  FROM tickets
 WHERE channel = 'CHATBOT_IA'
   AND description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, detail, created_at)
SELECT id, 'ROTEADO', 'ABERTO', 'EM_FILA', 'Fila MARKETPLACE: nenhum atendente online',
       created_at + NUMTODSINTERVAL(1, 'SECOND')
  FROM tickets
 WHERE channel = 'CHATBOT_IA'
   AND description = 'Meu pedido chegou incompleto: faltou o carregador.';

-- A conversa começou 4 minutos antes do ticket; a dúvida casou com o item 4.
INSERT INTO chatbot_conversations (user_id, segment, state, misses, current_faq_id, ticket_id,
                                   created_at, updated_at, finished_at)
SELECT t.user_id, 'PROBLEMA_PEDIDO', 'ENCAMINHADA', 0, f.id, t.id,
       t.created_at - NUMTODSINTERVAL(240, 'SECOND'), t.created_at, t.created_at
  FROM tickets t
  JOIN chatbot_faq f ON f.segment = 'PROBLEMA_PEDIDO' AND f.sort_order = 4
 WHERE t.channel = 'CHATBOT_IA'
   AND t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

-- As 8 mensagens, uma por INSERT para os ids seguirem a ordem da conversa.
INSERT INTO chatbot_messages (conversation_id, sender, body, created_at)
SELECT c.id, 'BOT', 'Olá, ' || REGEXP_SUBSTR(u.name, '[^ ]+')
       || '! Sou o Mentor Edu, o assistente do Edu. Sobre o que você precisa de ajuda?', c.created_at
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
  JOIN admin_users u ON u.id = c.user_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, option_id, created_at)
SELECT c.id, 'USER', 'Problemas com pedido', 'segment:PROBLEMA_PEDIDO', c.created_at + NUMTODSINTERVAL(15, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, created_at)
SELECT c.id, 'BOT', 'Estas são as dúvidas mais comuns sobre Problemas com pedido. Escolha uma ou escreva a sua.',
       c.created_at + NUMTODSINTERVAL(16, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, created_at)
SELECT c.id, 'USER', 'Meu pedido chegou incompleto: faltou o carregador.', c.created_at + NUMTODSINTERVAL(90, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, faq_id, created_at)
SELECT c.id, 'BOT', f.answer, f.id, c.created_at + NUMTODSINTERVAL(91, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
  JOIN chatbot_faq f ON f.id = c.current_faq_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, created_at)
SELECT c.id, 'BOT', 'Isso resolveu sua dúvida?', c.created_at + NUMTODSINTERVAL(92, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, option_id, created_at)
SELECT c.id, 'USER', 'Não resolveu', 'not_resolved', c.created_at + NUMTODSINTERVAL(180, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';

INSERT INTO chatbot_messages (conversation_id, sender, body, created_at)
SELECT c.id, 'BOT', 'Vou te passar para um atendente. Revise o pedido, anexe evidências se tiver e envie.',
       c.created_at + NUMTODSINTERVAL(181, 'SECOND')
  FROM chatbot_conversations c
  JOIN tickets t ON t.id = c.ticket_id
 WHERE t.description = 'Meu pedido chegou incompleto: faltou o carregador.';
