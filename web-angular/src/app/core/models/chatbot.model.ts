export type ChatbotSender = 'BOT' | 'USER';

export interface ChatbotMessage {
  id: number;
  sender: ChatbotSender;
  body: string;
  createdAt: string;
}

/** GET /tickets/{id}/chatbot-conversation: a conversa com o bot que abriu o ticket. */
export interface ChatbotTranscript {
  conversationId: number;
  startedAt: string;
  messages: ChatbotMessage[];
}
