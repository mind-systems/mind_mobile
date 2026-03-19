abstract class IMcpCoordinator {
  void dismiss();
  Future<String?> showCreateTokenSheet();
  Future<bool> showRevokeConfirmation();
}
