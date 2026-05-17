import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../data/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/auth_models.dart';
import '../data/models/user.dart';
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
final dioClientProvider = Provider((ref) => DioClient());
final authRepositoryProvider = Provider((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepository(dioClient);
});
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  AuthState({this.user, this.isLoading = false, this.error});
  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;
  late FlutterSecureStorage _secureStorage;
  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    _secureStorage = ref.watch(secureStorageProvider);
    _loadUser();
    return AuthState(isLoading: true);
  }
  Future<void> _loadUser() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token != null) {
        final user = await _repository.getCurrentUser();
        state = state.copyWith(user: user, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      await logout();
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  Future<bool> login(String identifier, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final req = LoginRequest(identifier: identifier, password: password);
      final data = await _repository.login(req);
      await _secureStorage.write(key: 'access_token', value: data['accessToken']);
      await _secureStorage.write(key: 'refresh_token', value: data['refreshToken']);
      final user = User.fromJson(data['user']);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
  Future<bool> register(RegisterRequest request) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final data = await _repository.register(request);
      await _secureStorage.write(key: 'access_token', value: data['accessToken']);
      await _secureStorage.write(key: 'refresh_token', value: data['refreshToken']);
      final user = User.fromJson(data['user']);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
  Future<bool> logout() async {
    try {
      state = state.copyWith(isLoading: true);
      await _repository.logout();
      await _secureStorage.deleteAll();
      state = AuthState(); 
      return true;
    } catch (e) {
      await _secureStorage.deleteAll();
      state = AuthState();
      return true;
    }
  }
}
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
