typedef OpenDoctorConsultation = Future<bool> Function(String conversationId);

class DoctorPortalNavigationRuntime {
  OpenDoctorConsultation? _openConsultation;

  void bindConsultationHandler(OpenDoctorConsultation handler) {
    _openConsultation = handler;
  }

  void unbindConsultationHandler() => _openConsultation = null;

  Future<bool> openConsultation(String conversationId) async {
    final handler = _openConsultation;
    if (handler == null || conversationId.trim().isEmpty) return false;
    return handler(conversationId.trim());
  }
}
