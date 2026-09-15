abstract interface class ConsultationConversationActivity {
  Future<void> openConversation(String conversationId);

  void closeConversation(String conversationId);

  Future<void> markConversationRead(String conversationId);
}
