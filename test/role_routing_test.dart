import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/constants/app_constants.dart';

void main() {
  group('Role routing', () {
    test('owners and staff land on the Admin Dashboard', () {
      expect(AppConstants.homeRouteForRole('admin'), '/parcels');
      expect(AppConstants.homeRouteForRole('staff'), '/parcels');
    });

    test('buyers land on the Customer Interface', () {
      expect(AppConstants.homeRouteForRole('customer'), '/customer');
    });

    test('legacy role spellings are normalised', () {
      expect(AppConstants.isStaffOrAdminRole('Admin'), isTrue);
      expect(AppConstants.isStaffOrAdminRole('  STAFF '), isTrue);
      expect(AppConstants.isAdminRole('ADMIN'), isTrue);
      expect(AppConstants.isAdminRole('staff'), isFalse);
      expect(AppConstants.isStaffOrAdminRole('Customer'), isFalse);
    });

    test('missing or unknown roles are treated as buyers', () {
      expect(AppConstants.isStaffOrAdminRole(null), isFalse);
      expect(AppConstants.isStaffOrAdminRole(''), isFalse);
      expect(AppConstants.isAdminRole(null), isFalse);
      expect(AppConstants.homeRouteForRole(null), '/customer');
      expect(AppConstants.homeRouteForRole('reseller'), '/customer');
    });
  });
}
