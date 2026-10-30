import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel_model.dart';
import '../../auth/presentation/auth_providers.dart';

final parcelRepositoryProvider = Provider<ParcelRepository>((ref) {
  return ParcelRepository();
});

// Stream of all parcels
final parcelsStreamProvider = StreamProvider<List<ParcelModel>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(parcelRepositoryProvider).getParcelsStream();
});

// Stream of single parcel by ID
final singleParcelStreamProvider =
    StreamProvider.family<ParcelModel?, String>((ref, id) {
  return ref.watch(parcelRepositoryProvider).getParcelByIdStream(id);
});

// Search query provider (Fixes searchQueryProvider error)
final searchQueryProvider = StateProvider<String>((ref) => '');
final parcelSearchQueryProvider = searchQueryProvider;

// Status & Platform filters
final selectedStatusFilterProvider = StateProvider<String?>((ref) => null);
final selectedPlatformFilterProvider = StateProvider<String?>((ref) => null);

// Filtered parcel list
final filteredParcelsProvider = Provider<List<ParcelModel>>((ref) {
  final parcels = ref.watch(parcelsStreamProvider).value ?? [];
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(selectedStatusFilterProvider);
  final platformFilter = ref.watch(selectedPlatformFilterProvider);

  return parcels.where((parcel) {
    final matchesQuery = query.isEmpty ||
        parcel.trackingNumber.toLowerCase().contains(query) ||
        parcel.customerName.toLowerCase().contains(query) ||
        (parcel.items ?? '').toLowerCase().contains(query);

    final matchesStatus = statusFilter == null || parcel.status == statusFilter;
    final matchesPlatform =
        platformFilter == null || parcel.platform == platformFilter;

    return matchesQuery && matchesStatus && matchesPlatform;
  }).toList();
});
