typedef OpenNotificationConsultation =
    Future<bool> Function(String conversationId);

class NotificationNavigationRuntime {
  OpenNotificationConsultation? _openConsultation;

  void bindConsultationHandler(OpenNotificationConsultation handler) {
    _openConsultation = handler;
  }

  void unbindConsultationHandler() => _openConsultation = null;

  Future<bool> openConsultation(String conversationId) async {
    final handler = _openConsultation;
    if (handler == null || conversationId.trim().isEmpty) return false;
    return handler(conversationId.trim());
  }
}
