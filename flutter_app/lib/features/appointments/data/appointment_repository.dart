import '../../../core/network/api_client.dart';
import '../domain/appointment_models.dart';

class AppointmentRepository implements AppointmentGateway {
  const AppointmentRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AppointmentDetail> loadAppointment(int appointmentId) async {
    final response = await _apiClient.get('/appointments/$appointmentId');
    return AppointmentDetail.fromJson(response);
  }
}
