import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/returns_repository.dart';
import '../domain/return_model.dart';
import '../../auth/presentation/auth_providers.dart';

export '../data/returns_repository.dart';
export '../domain/return_model.dart';

// Repository Provider
final returnsRepositoryProvider = Provider<ReturnsRepository>((ref) {
  return ReturnsRepository();
});

// Stream of all returns (auto re-subscribes when auth changes)
final returnsStreamProvider = StreamProvider<List<ReturnModel>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(returnsRepositoryProvider).getReturnsStream();
});

// Stream of single return ticket by ID
final singleReturnStreamProvider =
    StreamProvider.family<ReturnModel?, String>((ref, id) {
  return ref.watch(returnsRepositoryProvider).getReturnByIdStream(id);
});

// Search and filter states
final returnSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedReturnStatusFilterProvider =
    StateProvider<String?>((ref) => null);
final selectedDefectFilterProvider = StateProvider<String?>((ref) => null);

// Filtered returns list
final filteredReturnsProvider = Provider<List<ReturnModel>>((ref) {
  final returns = ref.watch(returnsStreamProvider).value ?? [];
  final query = ref.watch(returnSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(selectedReturnStatusFilterProvider);
  final defectFilter = ref.watch(selectedDefectFilterProvider);

  return returns.where((item) {
    final matchesQuery = query.isEmpty ||
        item.trackingNumber.toLowerCase().contains(query) ||
        item.customerName.toLowerCase().contains(query) ||
        (item.customPlateDetails ?? '').toLowerCase().contains(query);

    final matchesStatus = statusFilter == null || item.status == statusFilter;
    final matchesDefect =
        defectFilter == null || item.defectReason == defectFilter;

    return matchesQuery && matchesStatus && matchesDefect;
  }).toList();
});
