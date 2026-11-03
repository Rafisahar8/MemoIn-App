import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pengguna yang sedang login (hasil fungsi `app_login` di Supabase).
class AppUser {
  final String id;
  final String name;
  const AppUser({required this.id, required this.name});

  factory AppUser.fromMap(Map<String, dynamic> m) =>
      AppUser(id: '${m['id']}', name: '${m['name'] ?? ''}');
}

/// Login memakai username + password dari tabel `app_users`.
///
/// Verifikasi password dilakukan di database lewat fungsi RPC `app_login`
/// (bcrypt), jadi tabel `app_users` tidak pernah dibaca langsung dari aplikasi.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Null = belum login.
  final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  bool get isLoggedIn => user.value != null;

  Future<void> login(String username, String password) async {
    final name = username.trim();
    if (name.isEmpty || password.isEmpty) {
      throw const AuthFailure('Username dan password wajib diisi');
    }
    try {
      final res = await Supabase.instance.client.rpc(
        'app_login',
        params: {'p_name': name, 'p_password': password},
      );
      if (res is! Map) throw const AuthFailure('Respons login tidak valid');
      user.value = AppUser.fromMap(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      // Pesan dari fungsi SQL: "Username tidak ditemukan" / "Password salah".
      throw AuthFailure(e.message);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure('Tidak dapat terhubung ke server.\n$e');
    }
  }

  void logout() => user.value = null;
}

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}
