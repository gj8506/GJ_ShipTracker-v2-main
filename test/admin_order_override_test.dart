import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/features/admin/data/order_admin_repository.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/admin_order_requests_screen.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/order_admin_providers.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';

class _FakeOrderAdminRepository implements OrderAdminRepository {
  double? amount;
  String? orderId;
  String? adminUid;
  String? adminName;

  @override
  Future<void> updateFinalPrice({
    required String orderId,
    required double amount,
    required String adminUid,
    required String adminName,
  }) async {
    this.orderId = orderId;
    this.amount = amount;
    this.adminUid = adminUid;
    this.adminName = adminName;
  }
}

void main() {
  testWidgets('admin can override the final price of a submitted order',
      (tester) async {
    final repository = _FakeOrderAdminRepository();
    final order = <String, dynamic>{
      'id': 'order-123',
      'customerName': 'Maria Santos',
      'contactNumber': '09171234567',
      'deliveryAddress': 'Quezon City',
      'plateNumber': 'ABC 123',
      'plateStyle': 'custom',
      'region': 'NCR',
      'brandMake': 'Honda Click 125i',
      'plateSpecs': 'CUSTOM | Reg: NCR | Make: Honda Click 125i',
      'price': 1200.0,
      'estimatedPrice': 1200.0,
      'status': 'PENDING',
      'createdAt': DateTime(2026, 11, 4),
    };
    const admin = UserProfileModel(
      uid: 'admin-1',
      email: 'owner@gjandasher.com',
      fullName: 'Owner Account',
      role: 'admin',
    );

    final container = ProviderContainer(
      overrides: [
        adminOrderRequestsStreamProvider
            .overrideWith((ref) => Stream.value([order])),
        orderAdminRepositoryProvider.overrideWithValue(repository),
        userProfileProvider.overrideWith((ref) => Stream.value(admin)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminOrderRequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC 123'), findsOneWidget);
    expect(find.textContaining('1,200.00'), findsOneWidget);
    expect(find.text('Tap to set final price'), findsOneWidget);

    await tester.tap(find.text('Tap to set final price'));
    await tester.pumpAndSettle();

    expect(find.text('Order ABC 123'), findsOneWidget);
    expect(find.text('Estimated price'), findsOneWidget);

    await tester.tap(find.text('Set final price'));
    await tester.pumpAndSettle();

    expect(find.text('Override final price'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '1,750.50');
    await tester.tap(find.text('Save price'));
    await tester.pumpAndSettle();

    expect(repository.orderId, 'order-123');
    expect(repository.amount, 1750.50);
    expect(repository.adminUid, 'admin-1');
    expect(repository.adminName, 'Owner Account');
    expect(find.text('Final price updated for this order.'), findsOneWidget);
  });
}
