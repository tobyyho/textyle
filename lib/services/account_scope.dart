/// Binds a store to one authenticated account for its entire lifetime.
class AccountScope {
  AccountScope(this.userId, this.currentUserId);
  final String userId;
  final String? Function() currentUserId;
  void check() {
    if (userId.isEmpty || currentUserId() != userId) {
      throw StateError('Your account changed. Sign in again before saving.');
    }
  }
  String mediaPath(String reference) {
    check();
    final prefix = 'cloudmedia://$userId/';
    if (!reference.startsWith(prefix)) throw StateError('This asset belongs to another wardrobe.');
    final path = reference.substring('cloudmedia://'.length);
    if (path.split('/').any((p) => p.isEmpty || p == '.' || p == '..')) {
      throw const FormatException('Invalid wardrobe media reference.');
    }
    return path;
  }
}
