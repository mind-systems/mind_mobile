class ChangeEvent {
  final int id;
  final String entity;
  final String refId;
  final String action;

  ChangeEvent({
    required this.id,
    required this.entity,
    required this.refId,
    required this.action,
  });

  factory ChangeEvent.fromJson(Map<String, dynamic> json) => ChangeEvent(
    id: json['id'] as int,
    entity: json['entity'] as String,
    refId: json['refId'] as String,
    action: json['action'] as String,
  );
}
