import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';
import '../auth/session_controller.dart';

/// Yuqori o'ngdagi profil tugmasi (rangli sarlavhada ko'rinishi uchun och rangda).
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final name = s.profile?.fullName ?? '';
    final mail = s.user?.email ?? '';
    final initial = (name.isNotEmpty ? name[0] : (mail.isNotEmpty ? mail[0] : '?')).toUpperCase();
    return InkWell(
      onTap: () => context.push('/profile'),
      customBorder: const CircleBorder(),
      child: CircleAvatar(radius: 20, backgroundColor: AppColors.pale, foregroundColor: AppColors.forest,
          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800))),
    );
  }
}
