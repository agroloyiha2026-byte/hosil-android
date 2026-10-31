import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/region_dropdown.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../products/product_repository.dart';
import '../stage5_providers.dart';

class WarehouseListingFormScreen extends ConsumerStatefulWidget {
  const WarehouseListingFormScreen({super.key});

  @override
  ConsumerState<WarehouseListingFormScreen> createState() =>
      _WarehouseListingFormScreenState();
}

class _WarehouseListingFormScreenState
    extends ConsumerState<WarehouseListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _capacity = TextEditingController();
  final _freeSpace = TextEditingController();
  final _price = TextEditingController();
  final _address = TextEditingController();
  final _conditions = TextEditingController();
  final _phone = TextEditingController();
  final _accepted = TextEditingController();
  XFile? _image;
  String? _region;
  String _storageType = 'cold';
  String _currency = 'UZS';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _capacity,
      _freeSpace,
      _price,
      _address,
      _conditions,
      _phone,
      _accepted
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (image == null || !mounted) return;
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

  String? _positive(String? value) {
    final parsed = _number(value ?? '');
    return parsed == null || !parsed.isFinite || parsed <= 0
        ? context.tr('warehouse_invalid_number')
        : null;
  }

  Future<void> _submit() async {
    final user = ref.read(sessionProvider).user;
    if (user == null || !_form.currentState!.validate() || _region == null)
      return;
    if (_image == null) {
      setState(() => _error = context.tr('listing_image_required'));
      return;
    }
    final capacity = _number(_capacity.text)!;
    final freeSpace = _number(_freeSpace.text)!;
    if (freeSpace > capacity) {
      setState(() => _error = context.tr('warehouse_free_exceeds_capacity'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final imageUrl = await ProductRepository().uploadImage(_image!, user.id);
      await ref.read(warehouseRepoProvider).create(
            ownerId: user.id,
            name: _name.text,
            region: _region!,
            storageType: _storageType,
            capacityTons: capacity,
            freeTons: freeSpace,
            currency: _currency,
            imageUrl: imageUrl,
            pricePerTonMonth:
                _price.text.trim().isEmpty ? null : _number(_price.text),
            address: _address.text,
            conditions: _conditions.text,
            contactPhone: _phone.text,
            acceptedProducts: _accepted.text
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList(),
          );
      ref.invalidate(warehousesProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = errText(context, error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(sessionProvider.select((state) =>
        state.profile?.role == 'warehouse_owner' ||
        state.profile?.role == 'admin'));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('warehouse_add_listing'))),
      body: !allowed
          ? EmptyView(message: context.tr('action_role_needed'))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppTextField(
                      controller: _name,
                      label: context.tr('warehouse_name'),
                      validator: tv(context, Validators.required)),
                  const SizedBox(height: 12),
                  RegionDropdown(
                      label: context.tr('region'),
                      required: true,
                      value: _region,
                      onChanged: (value) => setState(() => _region = value)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _storageType,
                    decoration: InputDecoration(
                        labelText: context.tr('storage_type'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14))),
                    items: [
                      for (final type in const [
                        'cold',
                        'dry',
                        'vegetable',
                        'grain',
                        'other'
                      ])
                        DropdownMenuItem(
                            value: type, child: Text(context.tr('st_$type')))
                    ],
                    onChanged: (value) =>
                        setState(() => _storageType = value ?? 'cold'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _capacity,
                      label: context.tr('capacity'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _positive),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _freeSpace,
                      label: context.tr('free_space'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _positive),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _price,
                      label: context.tr('warehouse_price_optional'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return null;
                        final parsed = _number(value!);
                        return parsed == null || !parsed.isFinite || parsed < 0
                            ? context.tr('warehouse_invalid_number')
                            : null;
                      }),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                        labelText: context.tr('currency'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14))),
                    items: const [
                      DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                      DropdownMenuItem(value: 'USD', child: Text('USD'))
                    ],
                    onChanged: (value) =>
                        setState(() => _currency = value ?? 'UZS'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _accepted,
                      label: context.tr('warehouse_accepted_products')),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _address,
                      label: context.tr('warehouse_address')),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _conditions,
                      label: context.tr('conditions'),
                      maxLines: 3),
                  const SizedBox(height: 12),
                  if (_image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_image!.path),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    Text(_image!.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _image = null),
                        icon: const Icon(Icons.close),
                        label: Text(context.tr('remove_image')),
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context
                        .tr(_image == null ? 'pick_images' : 'replace_image')),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _phone,
                      label: context.tr('phone'),
                      keyboardType: TextInputType.phone,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? null
                          : tv(context, Validators.phone)(value)),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    ErrorText(_error)
                  ],
                  const SizedBox(height: 16),
                  AppButton(
                      label: context.tr('save'),
                      loading: _busy,
                      onPressed: _submit),
                ],
              ),
            ),
    );
  }
}
