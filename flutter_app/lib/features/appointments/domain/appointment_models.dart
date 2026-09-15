class AppointmentDetail {
  const AppointmentDetail({
    required this.id,
    required this.type,
    required this.status,
    required this.appointmentTime,
    this.nextAppointmentTime,
    this.symptoms = '',
    this.diagnosis = '',
    this.treatment = '',
    this.notes = '',
    this.petName = '',
    this.hospitalName = '',
    this.hospitalAddress = '',
    this.hospitalPhone = '',
    this.doctorName = '',
    this.doctorSpecialty = '',
  });

  factory AppointmentDetail.fromJson(Object? value) {
    final json = _jsonMap(value, 'appointment');
    final pet = _optionalJsonMap(json['pet']);
    final hospital = _optionalJsonMap(json['hospital']);
    final doctor = _optionalJsonMap(json['doctor']);
    return AppointmentDetail(
      id: _requiredPositiveInt(json['id'], 'appointment id'),
      type: AppointmentType.fromValue(json['type']),
      status: AppointmentStatus.fromValue(json['status']),
      appointmentTime: _requiredDateTime(
        json['appointmentTime'],
        'appointment time',
      ),
      nextAppointmentTime: _optionalDateTime(json['nextAppointmentTime']),
      symptoms: _string(json['symptoms']),
      diagnosis: _string(json['diagnosis']),
      treatment: _string(json['treatment']),
      notes: _string(json['notes']),
      petName: _string(pet?['name']),
      hospitalName: _string(hospital?['name']),
      hospitalAddress: _string(hospital?['address']),
      hospitalPhone: _string(hospital?['phone']),
      doctorName: _string(doctor?['name']),
      doctorSpecialty: _string(doctor?['specialty']),
    );
  }

  final int id;
  final AppointmentType type;
  final AppointmentStatus status;
  final DateTime appointmentTime;
  final DateTime? nextAppointmentTime;
  final String symptoms;
  final String diagnosis;
  final String treatment;
  final String notes;
  final String petName;
  final String hospitalName;
  final String hospitalAddress;
  final String hospitalPhone;
  final String doctorName;
  final String doctorSpecialty;
}

enum AppointmentType {
  vaccine('vaccine', '疫苗接种'),
  deworming('deworming', '驱虫'),
  checkup('checkup', '健康体检');

  const AppointmentType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AppointmentType fromValue(Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return values.firstWhere(
      (type) => type.wireValue == normalized,
      orElse: () => AppointmentType.checkup,
    );
  }
}

enum AppointmentStatus {
  pending('pending', '待确认'),
  confirmed('confirmed', '已确认'),
  inProgress('in_progress', '进行中'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  noShow('no_show', '未到诊');

  const AppointmentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AppointmentStatus fromValue(Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return values.firstWhere(
      (status) => status.wireValue == normalized,
      orElse: () => AppointmentStatus.pending,
    );
  }
}

abstract interface class AppointmentGateway {
  Future<AppointmentDetail> loadAppointment(int appointmentId);
}

Map<String, Object?> _jsonMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, item) => MapEntry('$key', item));
}

Map<String, Object?>? _optionalJsonMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry('$key', item));
}

int _requiredPositiveInt(Object? value, String label) {
  final parsed = switch (value) {
    final int number => number,
    final num number when number.isFinite => number.toInt(),
    _ => int.tryParse('$value'.trim()),
  };
  if (parsed == null || parsed <= 0) {
    throw FormatException('$label must be a positive integer.');
  }
  return parsed;
}

DateTime _requiredDateTime(Object? value, String label) {
  final parsed = _optionalDateTime(value);
  if (parsed == null) throw FormatException('$label must be a date time.');
  return parsed;
}

DateTime? _optionalDateTime(Object? value) {
  if (value is DateTime) return value;
  final normalized = _string(value);
  return normalized.isEmpty ? null : DateTime.tryParse(normalized);
}

String _string(Object? value) => value is String ? value.trim() : '';
