import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';
import '../domain/customer_model.dart';
import '../../auth/presentation/auth_providers.dart';

export '../data/customer_repository.dart';
export '../domain/customer_model.dart';

// Customer Repository Provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

// Stream of customers (auto-resyncs on auth changes)
final customersStreamProvider = StreamProvider<List<CustomerModel>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(customerRepositoryProvider).getCustomersStream();
});

// Search filter query
final customerSearchProvider = StateProvider<String>((ref) => '');

// Filtered customer list
final filteredCustomersProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(customersStreamProvider).value ?? [];
  final query = ref.watch(customerSearchProvider).trim().toLowerCase();

  if (query.isEmpty) return customers;

  return customers.where((c) {
    final nameMatches = c.name.toLowerCase().contains(query);
    final contactMatches = c.contactNumber.toLowerCase().contains(query);
    final typeMatches = c.type.toLowerCase().contains(query);
    return nameMatches || contactMatches || typeMatches;
  }).toList();
});
