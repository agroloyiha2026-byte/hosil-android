import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/region_dropdown.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../products/product_providers.dart';
import 'seller_verification.dart';
import '../settings/settings_controller.dart';

/// Stage 3 da asosiy ekran. Stage 4 da bosh sahifa va pastki navigatsiya qo'shilganda
/// bu ekran "Profil" yorlig'iga ko'chadi.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _S();
}

class _S extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(sessionProvider).profile?.fullName ?? '');
  late final _region = TextEditingController(text: ref.read(sessionProvider).profile?.region ?? '');
  late final _phone = TextEditingController(text: ref.read(sessionProvider).profile?.phone ?? '+998');
  late final _district = TextEditingController(text: ref.read(sessionProvider).profile?.district ?? '');
  late final _farm = TextEditingController(text: ref.read(sessionProvider).profile?.farmName ?? '');
  bool _busy = false;
  bool _editingProfile = false;
  String? _msg;
  bool _isErr = false;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    _phone.dispose();
    _district.dispose();
    _farm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = ref.read(sessionProvider).profile;
    if (p == null || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _msg = null; });
    try {
      await ref.read(authRepositoryProvider).updateProfile(p.id, fullName: _name.text, region: _region.text, phone: _phone.text, district: _district.text, farmName: _farm.text,
          language: ref.read(settingsProvider).locale.languageCode);
      await ref.read(sessionProvider.notifier).refreshProfile();
        if (mounted) { _msg = context.tr('saved_ok'); _isErr = false; _editingProfile = false; }
    } catch (e) {
      if (mounted) { _msg = errText(context, e); _isErr = true; }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAvatar() async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return;
      final url = await ref.read(productRepoProvider).uploadImage(image, userId);
      await ref.read(authRepositoryProvider).updateAvatar(userId, url);
      await ref.read(sessionProvider.notifier).refreshProfile();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final p = s.profile;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile')), actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          onTap: () => setState(() => _editingProfile = !_editingProfile),
          child: Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            backgroundImage: (p?.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(p!.avatarUrl!) : null,
            child: (p?.avatarUrl?.isNotEmpty ?? false)
              ? null
              : Text(((p?.fullName.isNotEmpty ?? false) ? p!.fullName[0] : (s.user?.email ?? '?')[0]).toUpperCase(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?.fullName.isEmpty ?? true ? '—' : p!.fullName, style: Theme.of(context).textTheme.titleMedium),
            Text(s.user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
            if (p != null) Text(context.tr('role_${p.role}'), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
          ])),
          IconButton(
            tooltip: context.tr('profile_photo'),
            onPressed: _busy ? null : _pickAvatar,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ])),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (p != null && (p.role == 'farmer' || p.isAdmin))
              ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text(context.tr('my_products')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/my-products')),
            ListTile(leading: const Icon(Icons.flag_outlined), title: Text(context.tr('goals_title')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/goals')),
            if (p?.role == 'farmer')
              ref.watch(sellerVerificationStatusProvider(p!.id)).when(
                loading: () => ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(context.tr('seller_verification_request')),
                  trailing: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(context.tr('seller_verification_request')),
                  subtitle: Text(errText(context, error)),
                ),
                data: (status) => ListTile(
                  leading: Icon(
                    status == 'verified' ? Icons.verified_user : Icons.verified_user_outlined,
                    color: status == 'verified' ? scheme.primary : null,
                  ),
                  title: Text(status == 'verified'
                      ? context.tr('seller_verified')
                      : status == 'pending'
                          ? context.tr('seller_verification_pending')
                          : status == 'rejected'
                              ? context.tr('seller_verification_rejected')
                              : context.tr('seller_verification_request')),
                  trailing: status == null || status == 'rejected'
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: status == null || status == 'rejected'
                      ? () => _requestSellerVerification(p.id)
                      : null,
                ),
              ),
            if (p != null && (p.role == 'farmer' || p.isAdmin))
              ListTile(leading: const Icon(Icons.qr_code_2_outlined), title: Text(context.tr('passport_title')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/passports')),
            if (p?.isAdmin == true)
              ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(context.tr('admin')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/admin')),
            ListTile(leading: const Icon(Icons.favorite_border), title: Text(context.tr('nav_favorites')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/favorites')),
            ListTile(leading: const Icon(Icons.mail_outline), title: Text(context.tr('inquiries')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/inquiries')),
            ListTile(leading: const Icon(Icons.notifications_none), title: Text(context.tr('notifications')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/notifications')),
            ListTile(leading: const Icon(Icons.warehouse_outlined), title: Text(context.tr('warehouses')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/warehouses')),
          ]),
        ),
        const SizedBox(height: 20),
        if (!_editingProfile)
          OutlinedButton.icon(
            onPressed: () => setState(() => _editingProfile = true),
            icon: const Icon(Icons.edit_outlined),
            label: Text(context.tr('edit_profile')),
          ),
        if (_editingProfile) ...[
        Text(context.tr('edit_profile'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: Column(children: [
            AppTextField(controller: _name, label: context.tr('full_name'), validator: tv(context, Validators.required)),
            const SizedBox(height: 14),
              RegionDropdown(label: context.tr('region'), required: true, value: _region.text.isEmpty ? null : _region.text, onChanged: (v) => setState(() => _region.text = v ?? '')),
              const SizedBox(height: 14),
              AppTextField(controller: _district, label: context.tr('district')),
              const SizedBox(height: 14),
              AppTextField(controller: _phone, label: context.tr('phone'), keyboardType: TextInputType.phone, validator: (v) {
                final value = v ?? '';
                return (value.trim().isEmpty || value.trim() == '+998') ? null : tv(context, Validators.phone)(value);
              }),
              const SizedBox(height: 14),
              if (s.user?.phoneConfirmedAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_user_outlined, color: scheme.primary),
                  title: Text(context.tr('phone_verified')),
                  subtitle: Text(s.user?.phone ?? ''),
                  trailing: TextButton(
                    onPressed: _busy ? null : _verifyPhone,
                    child: Text(context.tr('verify_phone')),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _verifyPhone,
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(context.tr('verify_phone')),
                  ),
                ),
              const SizedBox(height: 4),
              AppTextField(controller: _farm, label: context.tr('farm_name')),
          ]),
        ),
        const SizedBox(height: 16),
        if (_msg != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_msg!, style: TextStyle(color: _isErr ? scheme.error : scheme.primary))),
        AppButton(label: context.tr('save'), onPressed: p == null ? null : _save, loading: _busy),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() => _editingProfile = false), child: Text(context.tr('cancel'))),
        ],
        const SizedBox(height: 12),
        AppButton(label: context.tr('sign_out'), outlined: true, icon: Icons.logout, onPressed: () => ref.read(authRepositoryProvider).signOut()),
      ]),
    );
  }

  Future<void> _requestSellerVerification(String userId) async {
    try {
      await requestSellerVerification(userId, ref);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('phone_not_verified')
          ? context.tr('phone_verification_pending')
          : errText(context, error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _verifyPhone() async {
    final phone = _phone.text.trim();
    final validation = Validators.phone(phone);
    if (validation != null) {
      setState(() { _msg = context.tr(validation); _isErr = true; });
      return;
    }
    setState(() { _busy = true; _msg = null; });
    try {
      await ref.read(authRepositoryProvider).requestPhoneChangeOtp(phone);
      if (!mounted) return;
      setState(() => _busy = false);
      await _showPhoneOtpDialog(phone);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _msg = errText(context, e); _isErr = true; });
    }
  }

  Future<void> _showPhoneOtpDialog(String phone) async {
    final tokenController = TextEditingController();
    String? error;
    var verifying = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.tr('verify_phone')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialogContext.tr('phone_otp_sent')),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(labelText: dialogContext.tr('phone_otp_code')),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                ErrorText(error),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('cancel')),
            ),
            FilledButton(
              onPressed: verifying ? null : () async {
                setDialogState(() { verifying = true; error = null; });
                try {
                  final verified = await ref.read(authRepositoryProvider).verifyPhoneChangeOtp(
                    phone: phone,
                    token: tokenController.text,
                  );
                  if (!verified) throw StateError('phone_verification_incomplete');
                  await ref.read(sessionProvider.notifier).refreshProfile();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    setState(() { _msg = context.tr('phone_verified'); _isErr = false; });
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      verifying = false;
                      error = e is StateError && e.message == 'phone_verification_incomplete'
                          ? dialogContext.tr('phone_otp_failed')
                          : errText(dialogContext, e);
                    });
                  }
                }
              },
              child: Text(dialogContext.tr('verify')),
            ),
          ],
        ),
      ),
    );
    tokenController.dispose();
  }
}
