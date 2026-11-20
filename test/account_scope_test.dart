import 'package:flutter_test/flutter_test.dart';
import '../lib/services/account_scope.dart';
import '../lib/models/inventory_store.dart';

void main() {
  test('an authenticated owner can resolve their private asset', () {
    final scope = AccountScope('owner-a', () => 'owner-a');
    expect(scope.mediaPath('cloudmedia://owner-a/shirt/front.bin'), 'owner-a/shirt/front.bin');
  });
  test('another owner cannot be selected through a forged media reference', () {
    final scope = AccountScope('owner-a', () => 'owner-a');
    expect(() => scope.mediaPath('cloudmedia://owner-b/shirt/front.bin'), throwsStateError);
    expect(() => scope.mediaPath('cloudmedia://owner-a/../owner-b/front.bin'), throwsFormatException);
  });
  test('old stores fail after logout or account switch', () {
    String? current = 'owner-a';
    final scope = AccountScope('owner-a', () => current);
    scope.check();
    current = null;
    expect(scope.check, throwsStateError);
    current = 'owner-b';
    expect(scope.check, throwsStateError);
  });
  test('new account inventory starts empty and has no selected demo items', () async {
    final inventory = InventoryStore(initialItems: const [], persistence: MemoryInventoryPersistence());
    await inventory.load();
    expect(inventory.items, isEmpty);
    expect(inventory.selectedTop, isNull);
    expect(inventory.selectedBottom, isNull);
    inventory.dispose();
  });
}
