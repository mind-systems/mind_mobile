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
}
