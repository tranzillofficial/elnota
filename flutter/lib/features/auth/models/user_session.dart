/// Domain model for authenticated user and current workspace session.
class UserSession {
  const UserSession({
    required this.userId,
    required this.email,
    required this.workspaceId,
    this.workspaceName = 'Default Workspace',
    this.role = 'owner',
  });

  final String userId;
  final String email;
  final String workspaceId;
  final String workspaceName;
  final String role;

  bool get isOwner => role == 'owner';
}
