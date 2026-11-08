class ActivityLogModel {
  final String id;
  final DateTime timestamp;
  final String action;
  final String description;
  final String type; // 'success', 'warning', 'danger', 'info'

  const ActivityLogModel({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.description,
    this.type = 'info',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'description': description,
      'type': type,
    };
  }

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'] as String? ?? 'LOG-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      action: json['action'] as String? ?? 'Aktivitas',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
    );
  }
}

