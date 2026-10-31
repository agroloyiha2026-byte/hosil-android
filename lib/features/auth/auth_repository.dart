import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/profile.dart';
import '../../core/notifications/push_service.dart';

class AuthRepository {
  String? _nz(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();

  SupabaseClient get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// true qaytarsa: email tasdiqlash kerak (sessiya hali yo'q).
  Future<bool> signUp({required String email, required String password, required String fullName, required String role}) async {
    final res = await _c.auth.signUp(
      email: email.trim(), password: password, data: {'full_name': fullName.trim(), 'role': role});
    return res.session == null;
  }

  Future<void> resetPassword(String email) => _c.auth.resetPasswordForEmail(email.trim());

  Future<void> requestPhoneChangeOtp(String phone) async {
    await _c.auth.updateUser(UserAttributes(phone: phone.trim()));
  }

  Future<bool> verifyPhoneChangeOtp({required String phone, required String token}) async {
    await _c.auth.verifyOTP(
      type: OtpType.phoneChange,
      phone: phone.trim(),
      token: token.trim(),
    );
    final user = _c.auth.currentUser;
    final verified = user?.phoneConfirmedAt != null && user?.phone == phone.trim();
    if (verified && user != null) {
      await _c.from('profiles').update({'phone': phone.trim()}).eq('id', user.id);
    }
    return verified;
  }

  Future<void> signOut() async {
    try {
      await PushService.unregisterCurrentToken();
    } catch (error, stackTrace) {
      debugPrint('Could not unregister FCM token before sign-out: $error\n$stackTrace');
    }
    await _c.auth.signOut();
  }

  Future<Profile> fetchProfile(String id) async {
    final m = await _c.from('profiles')
        .select('id,full_name,role,language,region,onboarded,phone,district,farm_name,avatar_url').eq('id', id).single();
    return Profile.fromMap(m);
  }

  Future<void> updateAvatar(String id, String avatarUrl) async {
    await _c.from('profiles').update({'avatar_url': avatarUrl}).eq('id', id);
  }

  Future<void> updateProfile(String id, {required String fullName, String? region, required String language, String? phone, String? district, String? farmName}) async {
    await _c.from('profiles').update({
      'full_name': fullName.trim(), 'region': (region ?? '').trim().isEmpty ? null : region!.trim(), 'language': language,
      'phone': _nz(phone) == '+998' ? null : _nz(phone), 'district': _nz(district), 'farm_name': _nz(farmName),
    }).eq('id', id);
  }

  /// Birinchi kirishda: rolni (admin bo'lmasa) belgilaydi va profilni to'ldiradi.
  /// Talab: migration4.sql dagi set_my_role funksiyasi. Xavfsizlik server tomonda.
  Future<void> completeOnboarding({required Profile current, required String role, required String fullName,
      String? region, required String language, String? phone, String? district, String? farmName}) async {
    if (!current.isAdmin && role != current.role) {
      await _c.rpc('set_my_role', params: {'new_role': role});
    }
    await _c.from('profiles').update({
      'full_name': fullName.trim(), 'region': (region ?? '').trim().isEmpty ? null : region!.trim(),
      'language': language, 'onboarded': true,
      'phone': _nz(phone), 'district': _nz(district), 'farm_name': _nz(farmName),
    }).eq('id', current.id);
  }
}
