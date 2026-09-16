enum AgentIntent { health, shop, appointment, community, order }

class AgentPetSummary {
  const AgentPetSummary({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.breed,
    required this.weight,
    required this.tags,
  });

  factory AgentPetSummary.fromJson(Map<String, Object?> json) {
    return AgentPetSummary(
      id: _requiredInt(json['id'], 'agent pet id'),
      name: _requiredString(json['name'], 'agent pet name'),
      avatarUrl: json['avatar']?.toString().trim() ?? '',
      breed: json['breed']?.toString().trim() ?? '',
      weight: double.tryParse('${json['weight'] ?? 0}') ?? 0,
      tags: (json['tags'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }

  final int id;
  final String name;
  final String avatarUrl;
  final String breed;
  final double weight;
  final List<String> tags;
}

class AgentHomeContext {
  const AgentHomeContext({
    required this.primaryPet,
    required this.memory,
    required this.activeSessionId,
  });

  factory AgentHomeContext.fromJson(Map<String, Object?> json) {
    final pet = json['primaryPet'];
    return AgentHomeContext(
      primaryPet: pet is Map
          ? AgentPetSummary.fromJson(Map<String, Object?>.from(pet))
          : null,
      memory: json['memory']?.toString().trim(),
      activeSessionId: json['activeSessionId']?.toString().trim(),
    );
  }

  final AgentPetSummary? primaryPet;
  final String? memory;
  final String? activeSessionId;
}

class AgentRouteResult {
  const AgentRouteResult({
    required this.sessionId,
    required this.intent,
    required this.pet,
  });

  factory AgentRouteResult.fromJson(Map<String, Object?> json) {
    final rawIntent = _requiredString(json['intent'], 'agent intent');
    final pet = json['pet'];
    return AgentRouteResult(
      sessionId: _requiredString(json['sessionId'], 'agent session id'),
      intent: AgentIntent.values.byName(rawIntent.toLowerCase()),
      pet: pet is Map
          ? AgentPetSummary.fromJson(Map<String, Object?>.from(pet))
          : null,
    );
  }

  final AgentIntent intent;
  final AgentPetSummary? pet;
  final String sessionId;
}

abstract interface class AgentGateway {
  Future<AgentHomeContext> loadAgentHome();

  Future<AgentRouteResult> routeAgentMessage(
    String message, {
    int? petId,
    String? sessionId,
  });
}

String _requiredString(Object? value, String name) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$name must be a non-empty string.');
}

int _requiredInt(Object? value, String name) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}
