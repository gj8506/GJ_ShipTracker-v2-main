import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_profile_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

final userProfileProvider = StreamProvider<UserProfileModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUserProfile(authUser.uid);
});

// Alias in case other screens refer to currentUserProfileProvider
final currentUserProfileProvider = userProfileProvider;

/// Extracts the active user's role (e.g. 'admin', 'staff', 'rider', 'customer')
final currentUserRoleProvider = Provider<String?>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.value?.role;
});

/// Convenience boolean provider for checking admin status
final isAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role?.toLowerCase() == 'admin';
});

/// Convenience boolean provider for checking customer status (Module 9)
final isCustomerProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role?.toLowerCase() == 'customer';
});
