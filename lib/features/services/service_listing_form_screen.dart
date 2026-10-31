import 'dart:io';
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
import '../products/product_repository.dart';
import 'service_providers.dart';

class ServiceListingFormScreen extends ConsumerStatefulWidget {
  final String type;
  const ServiceListingFormScreen({super.key, required this.type});

  @override
  ConsumerState<ServiceListingFormScreen> createState() =>
      _ServiceListingFormScreenState();
}

class _ServiceListingFormScreenState
    extends ConsumerState<ServiceListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _unit = TextEditingController();
  final _phone = TextEditingController();
  XFile? _image;
  String? _region;
  String _currency = 'UZS';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _unit.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(sessionProvider).user;
    if (user == null || !_form.currentState!.validate() || _region == null)
      return;
    if (_image == null) {
      setState(() => _error = context.tr('listing_image_required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final imageUrl = await ProductRepository().uploadImage(_image!, user.id);
      await ref.read(serviceRepoProvider).create(
            ownerId: user.id,
            type: widget.type,
            title: _title.text,
            region: _region!,
            description: _description.text,
            currency: _currency,
            imageUrl: imageUrl,
            priceAmount: _price.text.trim().isEmpty
                ? null
                : double.parse(_price.text
                    .trim()
                    .replaceAll(' ', '')
                    .replaceAll(',', '.')),
            priceUnit: _unit.text,
            contactPhone: _phone.text,
          );
      ref.invalidate(myServiceListingsProvider(widget.type));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('service_submitted'))));
        context.pop();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = errText(context, e);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(sessionProvider.select((state) =>
        state.profile?.role == 'farmer' || state.profile?.role == 'admin'));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('add_service_listing'))),
      body: !allowed
          ? EmptyView(message: context.tr('action_role_needed'))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(context.tr('service_pending_note'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _title,
                    label: context.tr('service_title'),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return context.tr('v_required');
                      if (text.length < 3 || text.length > 120)
                        return context.tr('service_title_invalid');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  RegionDropdown(
                    label: context.tr('region'),
                    required: true,
                    value: _region,
                    onChanged: (value) => setState(() => _region = value),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _description,
                    label: context.tr('description'),
                    maxLines: 5,
                    validator: (value) => (value ?? '').trim().length < 10
                        ? context.tr('service_description_short')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _price,
                    label: context.tr('service_price_optional'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) return null;
                      final number = double.tryParse(value!
                          .trim()
                          .replaceAll(' ', '')
                          .replaceAll(',', '.'));
                      return number == null || !number.isFinite || number < 0
                          ? context.tr('service_price_invalid')
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: context.tr('currency'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (value) =>
                        setState(() => _currency = value ?? 'UZS'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _unit,
                      label: context.tr('service_price_unit')),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _phone,
                    label: context.tr('phone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? null
                        : tv(context, Validators.phone)(value),
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_image!.path),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    Text(_image!.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    TextButton.icon(
                      onPressed: () => setState(() => _image = null),
                      icon: const Icon(Icons.close),
                      label: Text(context.tr('remove_image')),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context
                        .tr(_image == null ? 'pick_images' : 'replace_image')),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    ErrorText(_error)
                  ],
                  const SizedBox(height: 12),
                  AppButton(
                      label: context.tr('save'),
                      loading: _busy,
                      onPressed: _submit),
                ],
              ),
            ),
    );
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (image == null) return;
    final size = await image.length();
    if (!mounted) return;
    if (imageContentType(image.name) == null || size > maxImageBytes) {
      setState(() => _error = context.tr('bad_image'));
      return;
    }
    setState(() {
      _image = image;
      _error = null;
    });
  }
}
