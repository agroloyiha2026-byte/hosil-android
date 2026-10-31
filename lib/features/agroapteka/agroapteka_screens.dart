import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/errors/app_error.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session_controller.dart';
import '../products/product_repository.dart';
import 'agroapteka_repository.dart';

final agroaptekaRepositoryProvider = Provider((ref) => AgroaptekaRepository());
final agroOwnerRefreshProvider = StateProvider<int>((ref) => 0);

class AgroaptekaScreen extends ConsumerStatefulWidget {
  const AgroaptekaScreen({super.key});
  @override
  ConsumerState<AgroaptekaScreen> createState() => _AgroaptekaScreenState();
}

class _AgroaptekaScreenState extends ConsumerState<AgroaptekaScreen> {
  final _search = TextEditingController(), _region = TextEditingController();
  late Future<List<AgroStore>> _stores;
  late Future<List<AgroProduct>> _products;
  late Future<List<AgroCategory>> _categories;
  int _tab = 0;
  String? _category;
  String _currency = 'UZS';
  bool _delivery = false, _inStock = false;
  double? _minPrice, _maxPrice;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _region.dispose();
    super.dispose();
  }

  void _refresh() {
    final repo = ref.read(agroaptekaRepositoryProvider);
    _stores = repo.stores(region: _region.text, delivery: _delivery);
    _products = repo.products(
      queryText: _search.text,
      category: _category,
      region: _region.text,
      currency: _currency,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      inStock: _inStock,
      delivery: _delivery,
    );
    _categories = repo.categories();
  }

  Future<void> _nearby() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('location_denied');
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().contains('location_denied')
              ? context.tr('agro_location_consent')
              : context.tr('error_generic')),
        ));
    }
  }

  Future<void> _filters() async {
    final min = TextEditingController(text: _minPrice?.toString() ?? '');
    final max = TextEditingController(text: _maxPrice?.toString() ?? '');
    var category = _category;
    var inStock = _inStock, delivery = _delivery, currency = _currency;
    late List<AgroCategory> categories;
    try {
      categories = await _categories;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(AppError.from(error).key))),
        );
      min.dispose();
      max.dispose();
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => Padding(
                padding: EdgeInsets.fromLTRB(
                    18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
                child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.tr('filters'),
                        style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: category,
                      decoration: InputDecoration(
                          labelText: ctx.tr('agro_filter_category')),
                      items: [
                        DropdownMenuItem<String?>(
                            value: null,
                            child: Text(ctx.tr('agro_filter_category'))),
                        for (final item in categories)
                          DropdownMenuItem<String?>(
                              value: item.slug,
                              child: Text(item.name(
                                  Localizations.localeOf(ctx).languageCode))),
                      ],
                      onChanged: (v) => set(() => category = v),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: min,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText:
                                      '${ctx.tr('agro_filter_price')} · min'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: max,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText:
                                      '${ctx.tr('agro_filter_price')} · max'))),
                    ]),
                    const SizedBox(height: 10),
                    Text(ctx.tr('agro_currency')),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'UZS', label: Text('UZS')),
                        ButtonSegment(value: 'USD', label: Text('USD')),
                      ],
                      selected: {currency},
                      onSelectionChanged: (values) =>
                          set(() => currency = values.first),
                    ),
                    SwitchListTile(
                        title: Text(ctx.tr('agro_filter_stock')),
                        value: inStock,
                        onChanged: (v) => set(() => inStock = v)),
                    SwitchListTile(
                        title: Text(ctx.tr('agro_filter_delivery')),
                        value: delivery,
                        onChanged: (v) => set(() => delivery = v)),
                    AppButton(
                        label: ctx.tr('apply'),
                        onPressed: () {
                          final parsedMin =
                              double.tryParse(min.text.replaceAll(',', '.'));
                          final parsedMax =
                              double.tryParse(max.text.replaceAll(',', '.'));
                          if ((min.text.trim().isNotEmpty &&
                                  (parsedMin == null ||
                                      !parsedMin.isFinite ||
                                      parsedMin < 0)) ||
                              (max.text.trim().isNotEmpty &&
                                  (parsedMax == null ||
                                      !parsedMax.isFinite ||
                                      parsedMax < 0)) ||
                              (parsedMin != null &&
                                  parsedMax != null &&
                                  parsedMin > parsedMax)) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(ctx.tr('agro_invalid_number'))),
                            );
                            return;
                          }
                          setState(() {
                            _category = category;
                            _inStock = inStock;
                            _delivery = delivery;
                            _currency = currency;
                            _minPrice = parsedMin;
                            _maxPrice = parsedMax;
                            _refresh();
                          });
                          Navigator.pop(ctx);
                        }),
                  ],
                )),
              )),
    );
    min.dispose();
    max.dispose();
  }

  double? _distance(AgroStore store) {
    if (_position == null ||
        store.latitude == null ||
        store.longitude == null ||
        !store.locationPublic) return null;
    const radius = 6371.0;
    final dLat = _rad(store.latitude! - _position!.latitude);
    final dLon = _rad(store.longitude! - _position!.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(_position!.latitude)) *
            math.cos(_rad(store.latitude!)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double value) => value * math.pi / 180;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('agroapteka')),
          actions: [
            IconButton(
                tooltip: context.tr('agro_requests'),
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => context.push('/agroapteka/my-inquiries')),
            IconButton(
                tooltip: context.tr('agro_owner_panel'),
                icon: const Icon(Icons.store_mall_directory_outlined),
                onPressed: () => context.push('/agroapteka/manage')),
            IconButton(
                tooltip: context.tr('agro_nearby'),
                icon: const Icon(Icons.my_location),
                onPressed: () async {
                  final consent = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: Text(ctx.tr('agro_location_consent')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(ctx.tr('cancel'))),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(ctx.tr('agro_nearby'))),
                      ],
                    ),
                  );
                  if (consent == true) await _nearby();
                }),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: _search,
                onSubmitted: (_) => setState(_refresh),
                decoration: InputDecoration(
                  hintText: context.tr('agro_search'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                      onPressed: () => setState(_refresh),
                      icon: const Icon(Icons.arrow_forward)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                  onPressed: _filters, icon: const Icon(Icons.tune)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _region,
              onSubmitted: (_) => setState(_refresh),
              decoration: InputDecoration(
                labelText: context.tr('agro_filter_region'),
                prefixIcon: const Icon(Icons.location_on_outlined),
                isDense: true,
                suffixIcon: IconButton(
                    onPressed: () => setState(_refresh),
                    icon: const Icon(Icons.search)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    label: Text(context.tr('agro_stores')),
                    icon: const Icon(Icons.storefront_outlined)),
                ButtonSegment(
                    value: 1,
                    label: Text(context.tr('agro_products')),
                    icon: const Icon(Icons.inventory_2_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
              child: _tab == 0
                  ? FutureBuilder<List<AgroStore>>(
                      future: _stores,
                      builder: (context, snap) {
                        if (snap.hasError)
                          return ErrorView(
                              error: snap.error!,
                              onRetry: () => setState(_refresh));
                        if (!snap.hasData) return const LoadingView();
                        final items = [...snap.data!];
                        if (_position != null) {
                          items.sort((a, b) => (_distance(a) ?? double.infinity)
                              .compareTo(_distance(b) ?? double.infinity));
                        }
                        if (items.isEmpty)
                          return EmptyView(
                              message: context.tr('agro_empty_stores'),
                              icon: Icons.store_outlined);
                        return RefreshIndicator(
                          onRefresh: () async => setState(_refresh),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _StoreCard(
                                store: items[i], distance: _distance(items[i])),
                          ),
                        );
                      },
                    )
                  : FutureBuilder<List<AgroProduct>>(
                      future: _products,
                      builder: (context, snap) {
                        if (snap.hasError)
                          return ErrorView(
                              error: snap.error!,
                              onRetry: () => setState(_refresh));
                        if (!snap.hasData) return const LoadingView();
                        if (snap.data!.isEmpty)
                          return EmptyView(
                              message: context.tr('agro_empty_products'),
                              icon: Icons.search_off);
                        return RefreshIndicator(
                          onRefresh: () async => setState(_refresh),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: snap.data!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ProductCard(
                                product: snap.data![i],
                                onOpen: () => _showProduct(snap.data![i])),
                          ),
                        );
                      },
                    )),
        ]),
      );

  Future<void> _showProduct(AgroProduct product) => showDialog<void>(
        context: context,
        builder: (ctx) => _ProductDialog(
          product: product,
          onInquiry: () async {
            final user = ref.read(sessionProvider).user;
            if (user == null) return;
            await _sendInquiry(ctx, product, user.id);
          },
          onReport: () =>
              _submitAgroReport(ctx, ref, product.storeId, product.id),
        ),
      );

  Future<void> _sendInquiry(BuildContext dialogContext, AgroProduct product,
      String customerId) async {
    final qty = TextEditingController(text: '1');
    final message = TextEditingController();
    final sent = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('agro_inquiry')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: ctx.tr('agro_quantity'))),
          TextField(
              controller: message,
              maxLines: 3,
              decoration: InputDecoration(labelText: ctx.tr('agro_message'))),
          const SizedBox(height: 8),
          Text(ctx.tr('agro_payment_unavailable'),
              style: Theme.of(ctx).textTheme.bodySmall),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('send'))),
        ],
      ),
    );
    if (sent == true) {
      final quantity = double.tryParse(qty.text.replaceAll(',', '.'));
      if (quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          quantity > product.stock) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
            quantity != null && quantity > product.stock
                ? context.tr('agro_not_enough_stock')
                : context.tr('agro_invalid_number'),
          )));
      } else {
        try {
          final inquiryId =
              await ref.read(agroaptekaRepositoryProvider).sendInquiry(
                    storeId: product.storeId,
                    productId: product.id,
                    customerId: customerId,
                    quantity: quantity,
                    message: message.text,
                  );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('agro_request_sent'))));
            Navigator.pop(dialogContext);
            context.push('/agroapteka/chat/$inquiryId');
          }
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('error_generic'))));
        }
      }
    }
    qty.dispose();
    message.dispose();
  }
}

class AgroStoreScreen extends ConsumerWidget {
  final String id;
  const AgroStoreScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(agroOwnerRefreshProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('agro_store_detail'))),
      body: FutureBuilder<List<AgroStore>>(
        future: ref.read(agroaptekaRepositoryProvider).stores(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorView(
                error: snapshot.error!,
                onRetry: () =>
                    ref.read(agroOwnerRefreshProvider.notifier).state++);
          if (!snapshot.hasData) return const LoadingView();
          final matches = snapshot.data!.where((store) => store.id == id);
          if (matches.isEmpty)
            return EmptyView(message: context.tr('agro_empty_stores'));
          final store = matches.first;
          return FutureBuilder<List<AgroProduct>>(
            future: ref
                .read(agroaptekaRepositoryProvider)
                .products(region: store.region),
            builder: (context, products) {
              if (products.hasError) return ErrorView(error: products.error!);
              if (!products.hasData) return const LoadingView();
              final items =
                  products.data!.where((p) => p.storeId == store.id).toList();
              return ListView(padding: const EdgeInsets.all(16), children: [
                _StoreCard(store: store),
                if (store.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(store.description!),
                ],
                if (store.openingHours?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text('${context.tr('agro_hours')}: ${store.openingHours}'),
                ],
                if (store.orderInfo?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text('${context.tr('agro_order_info')}: ${store.orderInfo}'),
                ],
                const SizedBox(height: 12),
                AppButton(
                    label: context.tr('agro_call'),
                    icon: Icons.call_outlined,
                    outlined: true,
                    onPressed: () => _launchExternal(
                        context, Uri(scheme: 'tel', path: store.phone))),
                const SizedBox(height: 8),
                AppButton(
                    label: context.tr('agro_report'),
                    icon: Icons.flag_outlined,
                    outlined: true,
                    onPressed: () =>
                        _submitAgroReport(context, ref, store.id, null)),
                if (store.locationPublic &&
                    store.latitude != null &&
                    store.longitude != null) ...[
                  const SizedBox(height: 8),
                  AppButton(
                      label: context.tr('agro_map'),
                      icon: Icons.map_outlined,
                      outlined: true,
                      onPressed: () => _openMap(context, store)),
                ],
                const SizedBox(height: 18),
                Text(context.tr('agro_products'),
                    style: Theme.of(context).textTheme.titleLarge),
                if (items.isEmpty)
                  EmptyView(message: context.tr('agro_empty_products')),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _ProductCard(
                      product: item,
                      onOpen: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => _ProductDialog(
                          product: item,
                          onReport: () => _submitAgroReport(
                              dialogContext, ref, item.storeId, item.id),
                          onInquiry: () async {
                            final userId = ref.read(sessionProvider).user?.id;
                            if (userId == null) return;
                            final quantity = TextEditingController(text: '1');
                            final message = TextEditingController();
                            final send = await showDialog<bool>(
                              context: dialogContext,
                              builder: (formContext) => AlertDialog(
                                title: Text(formContext.tr('agro_inquiry')),
                                content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: quantity,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                            labelText: formContext
                                                .tr('agro_quantity')),
                                      ),
                                      TextField(
                                        controller: message,
                                        decoration: InputDecoration(
                                            labelText:
                                                formContext.tr('agro_message')),
                                      ),
                                      Text(formContext
                                          .tr('agro_payment_unavailable')),
                                    ]),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(formContext, false),
                                    child: Text(formContext.tr('cancel')),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(formContext, true),
                                    child: Text(formContext.tr('send')),
                                  ),
                                ],
                              ),
                            );
                            if (send == true) {
                              final qty = double.tryParse(
                                  quantity.text.replaceAll(',', '.'));
                              if (qty == null ||
                                  !qty.isFinite ||
                                  qty <= 0 ||
                                  qty > item.stock) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(
                                    qty != null && qty > item.stock
                                        ? context.tr('agro_not_enough_stock')
                                        : context.tr('agro_invalid_number'),
                                  )));
                                }
                              } else {
                                try {
                                  final inquiryId = await ref
                                      .read(agroaptekaRepositoryProvider)
                                      .sendInquiry(
                                        storeId: item.storeId,
                                        productId: item.id,
                                        customerId: userId,
                                        quantity: qty,
                                        message: message.text,
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              context.tr('agro_request_sent'))),
                                    );
                                    Navigator.pop(dialogContext);
                                    context.push('/agroapteka/chat/$inquiryId');
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              context.tr('error_generic'))),
                                    );
                                  }
                                }
                              }
                            }
                            quantity.dispose();
                            message.dispose();
                          },
                        ),
                      ),
                    ),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class AgroInquiryChatScreen extends ConsumerStatefulWidget {
  final String inquiryId;
  const AgroInquiryChatScreen({super.key, required this.inquiryId});
  @override
  ConsumerState<AgroInquiryChatScreen> createState() =>
      _AgroInquiryChatScreenState();
}

class AgroCustomerInquiriesScreen extends ConsumerWidget {
  const AgroCustomerInquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(agroOwnerRefreshProvider);
    final userId = ref.watch(sessionProvider).user?.id;
    if (userId == null) return const LoadingView();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('agro_requests'))),
      body: FutureBuilder<List<AgroInquiry>>(
        future:
            ref.read(agroaptekaRepositoryProvider).customerInquiries(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorView(
                error: snapshot.error!,
                onRetry: () =>
                    ref.read(agroOwnerRefreshProvider.notifier).state++);
          if (!snapshot.hasData) return const LoadingView();
          if (snapshot.data!.isEmpty)
            return EmptyView(message: context.tr('agro_no_requests'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final inquiry in snapshot.data!)
                Card(
                    child: ListTile(
                  title: Text(
                      '${context.tr('agro_quantity')}: ${fmtNum(inquiry.quantity)}'),
                  subtitle: Text(
                      '${_inquiryStatus(context, inquiry.status)} · ${inquiry.message ?? ''}'),
                  trailing: const Icon(Icons.chat_outlined),
                  onTap: () => context.push('/agroapteka/chat/${inquiry.id}'),
                )),
            ],
          );
        },
      ),
    );
  }
}

class _AgroInquiryChatScreenState extends ConsumerState<AgroInquiryChatScreen> {
  final _message = TextEditingController();
  late Future<List<AgroInquiryMessage>> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _messages =
      ref.read(agroaptekaRepositoryProvider).inquiryMessages(widget.inquiryId);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sender = ref.read(sessionProvider).user?.id;
    if (sender == null || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(agroaptekaRepositoryProvider)
          .sendInquiryMessage(widget.inquiryId, sender, _message.text);
      _message.clear();
      setState(_load);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_generic'))),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(sessionProvider).user?.id;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('agro_requests'))),
      body: Column(children: [
        Expanded(
          child: FutureBuilder<List<AgroInquiryMessage>>(
            future: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return ErrorView(
                    error: snapshot.error!, onRetry: () => setState(_load));
              if (!snapshot.hasData) return const LoadingView();
              if (snapshot.data!.isEmpty)
                return EmptyView(
                    message: context.tr('agro_no_requests'),
                    icon: Icons.chat_outlined);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final message in snapshot.data!)
                    Align(
                      alignment: message.senderId == uid
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.senderId == uid
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(message.body),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: _message,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: context.tr('agro_message'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class AgroOwnerScreen extends ConsumerWidget {
  const AgroOwnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(sessionProvider).user?.id;
    ref.watch(agroOwnerRefreshProvider);
    if (ownerId == null) return const LoadingView();
    final repository = ref.read(agroaptekaRepositoryProvider);
    ref.watch(agroOwnerRefreshProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('agro_owner_panel'))),
      body: FutureBuilder<AgroStore?>(
        future: repository.ownStore(ownerId),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorView(
                error: snapshot.error!,
                onRetry: () =>
                    ref.read(agroOwnerRefreshProvider.notifier).state++);
          if (snapshot.connectionState != ConnectionState.done)
            return const LoadingView();
          final store = snapshot.data;
          if (store == null)
            return EmptyView(
              message: context.tr('agro_profile_required'),
              icon: Icons.store_mall_directory_outlined,
              actionLabel: context.tr('agro_apply'),
              onAction: () => context.push('/agroapteka/manage/profile'),
            );
          return FutureBuilder<List<AgroProduct>>(
            future: repository.ownProducts(store.id),
            builder: (context, productsSnap) {
              if (productsSnap.hasError)
                return ErrorView(error: productsSnap.error!);
              if (!productsSnap.hasData) return const LoadingView();
              return FutureBuilder<List<AgroInquiry>>(
                future: repository.ownInquiries(store.id),
                builder: (context, inquiriesSnap) {
                  if (inquiriesSnap.hasError)
                    return ErrorView(error: inquiriesSnap.error!);
                  if (!inquiriesSnap.hasData) return const LoadingView();
                  final products = productsSnap.data!;
                  final inquiries = inquiriesSnap.data!;
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: repository.privateStore(store.id),
                    builder: (context, privateSnap) {
                      if (privateSnap.hasError)
                        return ErrorView(error: privateSnap.error!);
                      if (!privateSnap.hasData) return const LoadingView();
                      final reviewNote = privateSnap.data!.isEmpty
                          ? null
                          : privateSnap.data!.first['admin_note'] as String?;
                      return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _StoreCard(store: store),
                            const SizedBox(height: 8),
                            Text(
                                '${context.tr('agro_store_status')}: ${_storeStatus(context, store.status)}'),
                            if (reviewNote?.isNotEmpty == true)
                              Text(reviewNote!),
                            if (store.companyName?.isNotEmpty == true)
                              Text(
                                  '${context.tr('agro_company')}: ${store.companyName}'),
                            if (store.responsiblePerson?.isNotEmpty == true)
                              Text(
                                  '${context.tr('agro_responsible')}: ${store.responsiblePerson}'),
                            if (store.email?.isNotEmpty == true)
                              Text(
                                  '${context.tr('agro_email')}: ${store.email}'),
                            if (store.legalDocumentUrl?.isNotEmpty == true)
                              Text(
                                  '${context.tr('agro_document')}: ${store.legalDocumentUrl}'),
                            const SizedBox(height: 10),
                            AppButton(
                                label: context.tr('agro_edit_store'),
                                icon: Icons.edit_outlined,
                                outlined: true,
                                onPressed: () =>
                                    context.push('/agroapteka/manage/profile')),
                            const SizedBox(height: 8),
                            AppButton(
                                label: context.tr('agro_new_product'),
                                icon: Icons.add,
                                onPressed: () => context
                                    .push('/agroapteka/manage/product/new')),
                            const SizedBox(height: 18),
                            Wrap(spacing: 8, children: [
                              Chip(
                                  label: Text(
                                      '${context.tr('agro_active_count')}: ${products.where((p) => p.published && p.moderationStatus == 'approved').length}')),
                              Chip(
                                  label: Text(
                                      '${context.tr('agro_available_count')}: ${products.where((p) => p.published && p.moderationStatus == 'approved' && p.stock > 0).length}')),
                              Chip(
                                  label: Text(
                                      '${context.tr('agro_new_request_count')}: ${inquiries.where((q) => q.status == 'new').length}')),
                            ]),
                            Text(
                                '${context.tr('agro_products_manage')} (${products.length})',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (products.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child:
                                    Text(context.tr('agro_no_products_owner')),
                              ),
                            for (final product in products)
                              Card(
                                  child: ListTile(
                                leading:
                                    _AgroImage(url: product.imageUrl, size: 48),
                                title: Text(product.title),
                                subtitle: Text(
                                    '${fmtNum(product.price)} ${product.currency} / ${product.unit} · ${context.tr('agro_product_status')}: ${_productStatus(context, product.moderationStatus)}${product.moderationNote?.isNotEmpty == true ? '\n${product.moderationNote}' : ''}'),
                                onTap: () => context.push(
                                    '/agroapteka/manage/product/${product.id}/edit'),
                                trailing: IconButton(
                                  tooltip: product.published
                                      ? context.tr('agro_hidden')
                                      : context.tr('agro_show'),
                                  icon: Icon(product.published
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () async {
                                    await repository.setProductPublished(
                                        product.id, !product.published);
                                    ref
                                        .read(agroOwnerRefreshProvider.notifier)
                                        .state++;
                                  },
                                ),
                              )),
                            const SizedBox(height: 20),
                            Text(
                                '${context.tr('agro_requests')} (${inquiries.length})',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (inquiries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(context.tr('agro_no_requests')),
                              ),
                            for (final inquiry in inquiries)
                              Card(
                                  child: ListTile(
                                title: Text(
                                    '${context.tr('agro_quantity')}: ${fmtNum(inquiry.quantity)}'),
                                subtitle: Text(
                                    '${_inquiryStatus(context, inquiry.status)} · ${inquiry.message ?? ''}'),
                                onTap: () => context
                                    .push('/agroapteka/chat/${inquiry.id}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (status) async {
                                    await repository.updateInquiry(
                                        inquiry.id, status);
                                    ref
                                        .read(agroOwnerRefreshProvider.notifier)
                                        .state++;
                                  },
                                  itemBuilder: (_) => [
                                    for (final status in const [
                                      'reviewing',
                                      'accepted',
                                      'rejected',
                                      'completed'
                                    ])
                                      PopupMenuItem(
                                          value: status,
                                          child: Text(
                                              _inquiryStatus(context, status))),
                                  ],
                                ),
                              )),
                          ]);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class AgroStoreFormScreen extends ConsumerStatefulWidget {
  const AgroStoreFormScreen({super.key});
  @override
  ConsumerState<AgroStoreFormScreen> createState() =>
      _AgroStoreFormScreenState();
}

class _AgroStoreFormScreenState extends ConsumerState<AgroStoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {
    for (final name in const [
      'name',
      'company',
      'responsible',
      'phone',
      'email',
      'region',
      'district',
      'address',
      'latitude',
      'longitude',
      'hours',
      'image',
      'description',
      'deliveryArea',
      'orderInfo',
      'document',
    ])
      name: TextEditingController(),
  };
  bool _locationPublic = false,
      _deliveryEnabled = false,
      _loading = true,
      _saving = false;
  XFile? _imageFile;
  Uint8List? _imagePreview;
  String? _storeId, _error;

  TextEditingController field(String key) => _fields[key]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null) return;
    try {
      final repo = ref.read(agroaptekaRepositoryProvider);
      final store = await repo.ownStore(uid);
      if (store != null) {
        _storeId = store.id;
        field('name').text = store.name;
        field('phone').text = store.phone;
        field('region').text = store.region;
        field('district').text = store.district ?? '';
        field('address').text = store.address;
        field('latitude').text = store.latitude?.toString() ?? '';
        field('longitude').text = store.longitude?.toString() ?? '';
        field('hours').text = store.openingHours ?? '';
        field('image').text = store.imageUrl ?? '';
        field('description').text = store.description ?? '';
        field('deliveryArea').text = store.deliveryArea ?? '';
        field('orderInfo').text = store.orderInfo ?? '';
        _locationPublic = store.locationPublic;
        _deliveryEnabled = store.deliveryEnabled;
        final privateRows = await repo.privateStore(store.id);
        if (privateRows.isNotEmpty) {
          final data = privateRows.first;
          field('latitude').text = store.latitude?.toString() ??
              (data['latitude'] as num?)?.toString() ??
              '';
          field('longitude').text = store.longitude?.toString() ??
              (data['longitude'] as num?)?.toString() ??
              '';
          field('company').text = data['company_name'] as String? ?? '';
          field('responsible').text =
              data['responsible_person'] as String? ?? '';
          field('email').text = data['email'] as String? ?? '';
          field('document').text = data['legal_document_url'] as String? ?? '';
        }
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ownerId = ref.read(sessionProvider).user?.id;
    if (ownerId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final imageUrl = _imageFile == null
          ? field('image').text
          : await ProductRepository().uploadImage(_imageFile!, ownerId);
      await ref.read(agroaptekaRepositoryProvider).saveStore(
            storeId: _storeId,
            ownerId: ownerId,
            name: field('name').text,
            phone: field('phone').text,
            region: field('region').text,
            district: field('district').text,
            address: field('address').text,
            latitude: field('latitude').text,
            longitude: field('longitude').text,
            locationPublic: _locationPublic,
            openingHours: field('hours').text,
            imageUrl: imageUrl,
            description: field('description').text,
            deliveryEnabled: _deliveryEnabled,
            deliveryArea: field('deliveryArea').text,
            orderInfo: field('orderInfo').text,
            companyName: field('company').text,
            responsiblePerson: field('responsible').text,
            email: field('email').text,
            legalDocumentUrl: field('document').text,
          );
      ref.read(agroOwnerRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('agro_store_saved'))));
        context.pop();
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = error is FormatException
            ? context.tr('agro_invalid_coordinates')
            : context.tr(AppError.from(error).key));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (imageContentType(file.name) == null || bytes.length > maxImageBytes) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('bad_image'))),
        );
      return;
    }
    if (mounted)
      setState(() {
        _imageFile = file;
        _imagePreview = bytes;
      });
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.tr('agro_required') : null;

  Widget _text(String key, String label,
          {bool required = false,
          TextInputType? keyboardType,
          int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: field(key),
          keyboardType: keyboardType,
          maxLines: lines,
          validator: required ? _required : null,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('agro_edit_store'))),
        body: _loading
            ? const LoadingView()
            : _error != null && _storeId == null
                ? ErrorView(error: _error!)
                : Form(
                    key: _formKey,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      if (_error != null)
                        Text(context.tr('error_generic'),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      _text('name', context.tr('agro_store_name'),
                          required: true),
                      _text('company', context.tr('agro_company')),
                      _text('responsible', context.tr('agro_responsible')),
                      _text('phone', context.tr('agro_phone'),
                          required: true, keyboardType: TextInputType.phone),
                      _text('email', context.tr('agro_email'),
                          keyboardType: TextInputType.emailAddress),
                      _text('region', context.tr('agro_region'),
                          required: true),
                      _text('district', context.tr('agro_district')),
                      _text('address', context.tr('agro_address'),
                          required: true),
                      Row(children: [
                        Expanded(
                            child: _text(
                                'latitude', context.tr('agro_latitude'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _text(
                                'longitude', context.tr('agro_longitude'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true))),
                      ]),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _locationPublic,
                        title: Text(context.tr('agro_public_location')),
                        onChanged: (value) =>
                            setState(() => _locationPublic = value),
                      ),
                      _text('hours', context.tr('agro_hours')),
                      if (_imagePreview != null ||
                          field('image').text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _imagePreview != null
                              ? Image.memory(_imagePreview!,
                                  height: 140, fit: BoxFit.cover)
                              : _AgroImage(url: field('image').text, size: 140),
                        ),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(context.tr('pick_image')),
                      ),
                      _text('image', context.tr('agro_image_url')),
                      _text('description', context.tr('agro_description'),
                          lines: 3),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _deliveryEnabled,
                        title: Text(context.tr('agro_delivery_toggle')),
                        onChanged: (value) =>
                            setState(() => _deliveryEnabled = value),
                      ),
                      if (_deliveryEnabled)
                        _text('deliveryArea', context.tr('agro_delivery_area')),
                      _text('orderInfo', context.tr('agro_order_info'),
                          lines: 2),
                      const Divider(height: 28),
                      Text(context.tr('agro_company'),
                          style: Theme.of(context).textTheme.titleMedium),
                      _text('document', context.tr('agro_document')),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(context.tr('agro_pending'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      AppButton(
                          label: context.tr('agro_save'),
                          loading: _saving,
                          onPressed: _save),
                    ]),
                  ),
      );
}

class AgroProductFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const AgroProductFormScreen({super.key, this.id});
  @override
  ConsumerState<AgroProductFormScreen> createState() =>
      _AgroProductFormScreenState();
}

class _AgroProductFormScreenState extends ConsumerState<AgroProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {
    for (final name in const [
      'title',
      'description',
      'image',
      'price',
      'unit',
      'stock',
      'manufacturer',
      'package',
      'expiry',
      'ingredient',
      'instructions',
      'storage',
      'safety',
    ])
      name: TextEditingController(),
  };
  AgroStore? _store;
  AgroProduct? _product;
  List<AgroCategory> _categories = [];
  String? _category, _error;
  String _currency = 'UZS';
  XFile? _imageFile;
  Uint8List? _imagePreview;
  bool _loading = true, _saving = false;

  TextEditingController field(String key) => _fields[key]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ownerId = ref.read(sessionProvider).user?.id;
      if (ownerId == null) throw StateError('missing_session');
      final repo = ref.read(agroaptekaRepositoryProvider);
      _store = await repo.ownStore(ownerId);
      if (_store == null) throw StateError('store_profile_missing');
      _categories = await repo.categories();
      if (widget.id != null) {
        final products = await repo.ownProducts(_store!.id);
        final matches = products.where((p) => p.id == widget.id);
        _product = matches.isEmpty ? null : matches.first;
        if (_product == null) throw StateError('product_not_found');
        final p = _product!;
        field('title').text = p.title;
        field('description').text = p.description ?? '';
        field('image').text = p.imageUrl ?? '';
        field('price').text = p.price.toString();
        field('unit').text = p.unit;
        field('stock').text = p.stock.toString();
        field('manufacturer').text = p.manufacturer ?? '';
        field('package').text = p.packageSize ?? '';
        field('expiry').text = p.expiryDate ?? '';
        field('ingredient').text = p.activeIngredient ?? '';
        field('instructions').text = p.instructionsUrl ?? '';
        field('storage').text = p.storageConditions ?? '';
        field('safety').text = p.safetyWarning ?? '';
        _category = p.category;
        _currency = p.currency;
      } else if (_categories.isNotEmpty) {
        _category = _categories.first.slug;
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.tr('agro_required') : null;

  Widget _text(String key, String label,
          {bool required = false,
          TextInputType? keyboardType,
          int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: field(key),
          keyboardType: keyboardType,
          maxLines: lines,
          validator: required ? _required : null,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _store == null ||
        _category == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ownerId = ref.read(sessionProvider).user!.id;
      final imageUrl = _imageFile == null
          ? field('image').text
          : await ProductRepository().uploadImage(_imageFile!, ownerId);
      await ref.read(agroaptekaRepositoryProvider).saveProduct(
            id: widget.id,
            storeId: _store!.id,
            title: field('title').text,
            category: _category!,
            description: field('description').text,
            imageUrl: imageUrl,
            price: field('price').text,
            currency: _currency,
            unit: field('unit').text,
            stock: field('stock').text,
            manufacturer: field('manufacturer').text,
            packageSize: field('package').text,
            expiryDate: field('expiry').text,
            activeIngredient: field('ingredient').text,
            instructionsUrl: field('instructions').text,
            storageConditions: field('storage').text,
            safetyWarning: field('safety').text,
          );
      ref.read(agroOwnerRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('agro_product_saved'))));
        context.pop();
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = error is FormatException
            ? error.message == 'invalid_expiry'
                ? context.tr('agro_bad_expiry')
                : context.tr('agro_bad_price_stock')
            : context.tr(AppError.from(error).key));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (imageContentType(file.name) == null || bytes.length > maxImageBytes) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('bad_image'))),
        );
      return;
    }
    if (mounted)
      setState(() {
        _imageFile = file;
        _imagePreview = bytes;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(context.tr(widget.id == null
                ? 'agro_new_product'
                : 'agro_product_detail'))),
        body: _loading
            ? const LoadingView()
            : _error != null && _store == null
                ? ErrorView(error: _error!)
                : Form(
                    key: _formKey,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      _text('title', context.tr('agro_product_name'),
                          required: true),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                            labelText: context.tr('agro_category')),
                        items: [
                          for (final item in _categories)
                            DropdownMenuItem(
                                value: item.slug,
                                child: Text(item.name(
                                    Localizations.localeOf(context)
                                        .languageCode)))
                        ],
                        onChanged: (value) => setState(() => _category = value),
                        validator: (value) =>
                            value == null ? context.tr('agro_required') : null,
                      ),
                      const SizedBox(height: 12),
                      _text('price', context.tr('agro_price'),
                          required: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'UZS', label: Text('UZS')),
                          ButtonSegment(value: 'USD', label: Text('USD'))
                        ],
                        selected: {_currency},
                        onSelectionChanged: (values) =>
                            setState(() => _currency = values.first),
                      ),
                      const SizedBox(height: 12),
                      _text('unit', context.tr('agro_unit'), required: true),
                      _text('stock', context.tr('agro_stock'),
                          required: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                      if (_imagePreview != null ||
                          field('image').text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _imagePreview != null
                              ? Image.memory(_imagePreview!,
                                  height: 140, fit: BoxFit.cover)
                              : _AgroImage(url: field('image').text, size: 140),
                        ),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(context.tr('pick_image')),
                      ),
                      _text('image', context.tr('agro_image_url')),
                      _text('description', context.tr('agro_description'),
                          lines: 3),
                      _text('manufacturer', context.tr('agro_manufacturer')),
                      _text('package', context.tr('agro_package')),
                      _text('expiry', context.tr('agro_expiry')),
                      _text('ingredient', context.tr('agro_ingredient')),
                      _text('instructions', context.tr('agro_instructions')),
                      _text('storage', context.tr('agro_storage'), lines: 2),
                      _text('safety', context.tr('agro_safety'), lines: 2),
                      const SizedBox(height: 8),
                      AppButton(
                          label: context.tr('agro_save'),
                          loading: _saving,
                          onPressed: _save),
                    ]),
                  ),
      );
}

class AgroAdminScreen extends ConsumerWidget {
  const AgroAdminScreen({super.key});

  Future<
      (
        List<AgroStore>,
        List<AgroProduct>,
        List<AgroReport>,
        List<Map<String, dynamic>>
      )> _load(AgroaptekaRepository repo) async {
    final result = await Future.wait<Object>([
      repo.allStores(),
      repo.pendingProducts(),
      repo.openReports(),
      repo.moderationHistory(),
    ]);
    return (
      result[0] as List<AgroStore>,
      result[1] as List<AgroProduct>,
      result[2] as List<AgroReport>,
      result[3] as List<Map<String, dynamic>>,
    );
  }

  Future<String?> _reason(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('agro_admin_note')),
        content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(hintText: ctx.tr('agro_admin_note'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(ctx.tr('agro_reject'))),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(agroaptekaRepositoryProvider);
    ref.watch(agroOwnerRefreshProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('agro_moderation'))),
      body: FutureBuilder<
          (
            List<AgroStore>,
            List<AgroProduct>,
            List<AgroReport>,
            List<Map<String, dynamic>>
          )>(
        future: _load(repo),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorView(
                error: snapshot.error!,
                onRetry: () =>
                    ref.read(agroOwnerRefreshProvider.notifier).state++);
          if (!snapshot.hasData) return const LoadingView();
          final stores = snapshot.data!.$1;
          final pendingStores =
              stores.where((store) => store.status == 'pending').toList();
          final activeStores =
              stores.where((store) => store.status == 'approved').toList();
          final products = snapshot.data!.$2;
          final reports = snapshot.data!.$3;
          final history = snapshot.data!.$4;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(context.tr('agro_pending_stores'),
                style: Theme.of(context).textTheme.titleLarge),
            if (pendingStores.isEmpty) Text(context.tr('agro_pending')),
            for (final store in pendingStores)
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '${store.region} · ${store.address} · ${store.phone}'),
                      if (store.companyName?.isNotEmpty == true)
                        Text(
                            '${context.tr('agro_company')}: ${store.companyName}'),
                      if (store.responsiblePerson?.isNotEmpty == true)
                        Text(
                            '${context.tr('agro_responsible')}: ${store.responsiblePerson}'),
                      if (store.email?.isNotEmpty == true)
                        Text('${context.tr('agro_email')}: ${store.email}'),
                      if (store.legalDocumentUrl?.isNotEmpty == true)
                        TextButton.icon(
                          onPressed: () {
                            final uri = Uri.tryParse(store.legalDocumentUrl!);
                            if (uri != null &&
                                (uri.scheme == 'https' ||
                                    uri.scheme == 'http')) {
                              launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.description_outlined),
                          label: Text(context.tr('agro_document')),
                        ),
                      if (store.adminNote?.isNotEmpty == true)
                        Text(
                            '${context.tr('agro_admin_note')}: ${store.adminNote}'),
                      const SizedBox(height: 8),
                      Text(
                          '${context.tr('agro_store_status')}: ${_storeStatus(context, store.status)}'),
                      if (store.status == 'pending')
                        Row(children: [
                          Expanded(
                              child: FilledButton(
                                  onPressed: () async {
                                    try {
                                      await repo.reviewStore(
                                          store.id, 'approved', null);
                                      ref
                                          .read(
                                              agroOwnerRefreshProvider.notifier)
                                          .state++;
                                    } catch (_) {
                                      if (context.mounted)
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(context
                                                    .tr('error_generic'))));
                                    }
                                  },
                                  child: Text(context.tr('agro_approve')))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: () async {
                                    final note = await _reason(context);
                                    if (note == null || note.trim().isEmpty) {
                                      if (context.mounted && note != null)
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(context.tr(
                                                    'agro_note_required'))));
                                      return;
                                    }
                                    try {
                                      await repo.reviewStore(
                                          store.id, 'rejected', note);
                                      ref
                                          .read(
                                              agroOwnerRefreshProvider.notifier)
                                          .state++;
                                    } catch (_) {
                                      if (context.mounted)
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(context
                                                    .tr('error_generic'))));
                                    }
                                  },
                                  child: Text(context.tr('agro_reject')))),
                        ]),
                    ]),
              )),
            const SizedBox(height: 20),
            Text(context.tr('agro_status_approved'),
                style: Theme.of(context).textTheme.titleLarge),
            for (final store in activeStores)
              Card(
                  child: ListTile(
                title: Text(store.name),
                subtitle: Text('${store.region} · ${store.address}'),
                trailing: IconButton(
                  tooltip: context.tr('agro_suspended'),
                  icon: const Icon(Icons.block_outlined),
                  onPressed: () async {
                    final note = await _reason(context);
                    if (note == null || note.trim().isEmpty) return;
                    try {
                      await repo.reviewStore(store.id, 'suspended', note);
                      ref.read(agroOwnerRefreshProvider.notifier).state++;
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(context.tr('error_generic'))));
                    }
                  },
                ),
              )),
            const SizedBox(height: 20),
            Text(context.tr('agro_pending_products'),
                style: Theme.of(context).textTheme.titleLarge),
            if (products.isEmpty) Text(context.tr('agro_pending')),
            for (final product in products)
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '${product.store?.name ?? ''} · ${product.category} · ${product.price} ${product.currency}'),
                      if (product.moderationNote?.isNotEmpty == true)
                        Text(product.moderationNote!),
                      if (product.safetyWarning?.isNotEmpty == true)
                        Text(product.safetyWarning!),
                      Row(children: [
                        Expanded(
                            child: FilledButton(
                                onPressed: () async {
                                  try {
                                    await repo.reviewProduct(
                                        product.id, 'approved', null);
                                    ref
                                        .read(agroOwnerRefreshProvider.notifier)
                                        .state++;
                                  } catch (_) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(context
                                                  .tr('error_generic'))));
                                  }
                                },
                                child: Text(context.tr('agro_approve')))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () async {
                                  final note = await _reason(context);
                                  if (note == null || note.trim().isEmpty) {
                                    if (context.mounted && note != null)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(context
                                                  .tr('agro_note_required'))));
                                    return;
                                  }
                                  try {
                                    await repo.reviewProduct(
                                        product.id, 'rejected', note);
                                    ref
                                        .read(agroOwnerRefreshProvider.notifier)
                                        .state++;
                                  } catch (_) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(context
                                                  .tr('error_generic'))));
                                  }
                                },
                                child: Text(context.tr('agro_reject')))),
                      ]),
                    ]),
              )),
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.block_outlined),
                  label: Text(context.tr('agro_block')),
                  onPressed: () async {
                    final note = await _reason(context);
                    if (note == null || note.trim().isEmpty) return;
                    try {
                      await repo.reviewProduct(product.id, 'blocked', note);
                      ref.read(agroOwnerRefreshProvider.notifier).state++;
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(context.tr('error_generic'))));
                    }
                  },
                ),
              ),
            const SizedBox(height: 20),
            AppButton(
                label: context.tr('agro_categories_manage'),
                icon: Icons.category_outlined,
                outlined: true,
                onPressed: () => context.push('/admin/agroapteka/categories')),
            const SizedBox(height: 20),
            Text(context.tr('agro_reports'),
                style: Theme.of(context).textTheme.titleLarge),
            if (reports.isEmpty) Text(context.tr('agro_no_reports')),
            for (final report in reports)
              Card(
                  child: ListTile(
                title: Text(
                    report.productName ?? report.storeName ?? report.storeId),
                subtitle: Text(report.reason),
                trailing: IconButton(
                  tooltip: context.tr('agro_resolve'),
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () async {
                    try {
                      await repo.resolveReport(report.id, '');
                      ref.read(agroOwnerRefreshProvider.notifier).state++;
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(context.tr('error_generic'))));
                    }
                  },
                ),
              )),
            const SizedBox(height: 20),
            Text(context.tr('agro_history'),
                style: Theme.of(context).textTheme.titleLarge),
            for (final entry in history)
              ListTile(
                dense: true,
                title: Text(
                    '${entry['action'] ?? ''} · ${entry['entity_id'] ?? ''}'),
                subtitle: Text('${entry['created_at'] ?? ''}'),
              ),
          ]);
        },
      ),
    );
  }
}

class AgroCategoryAdminScreen extends ConsumerWidget {
  const AgroCategoryAdminScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref,
      {AgroCategory? existing}) async {
    final fields = List.generate(5, (_) => TextEditingController());
    if (existing != null) {
      fields[0].text = existing.slug;
      fields[1].text = existing.nameUz;
      fields[2].text = existing.nameRu;
      fields[3].text = existing.nameEn;
      fields[4].text = existing.sortOrder.toString();
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('agro_category_add')),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < fields.length; i++)
            TextField(
              controller: fields[i],
              keyboardType: i == 4 ? TextInputType.number : TextInputType.text,
              enabled: existing == null || i != 0,
              decoration: InputDecoration(
                  labelText: [
                ctx.tr('agro_category_slug'),
                ctx.tr('agro_category_uz'),
                ctx.tr('agro_category_ru'),
                ctx.tr('agro_category_en'),
                ctx.tr('agro_sort_order'),
              ][i]),
            ),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('agro_save'))),
        ],
      ),
    );
    if (saved == true) {
      final order = int.tryParse(fields[4].text) ?? 0;
      try {
        await ref.read(agroaptekaRepositoryProvider).saveCategory(
              slug: fields[0].text,
              nameUz: fields[1].text,
              nameRu: fields[2].text,
              nameEn: fields[3].text,
              sortOrder: order,
              active: existing?.active ?? true,
            );
        ref.read(agroOwnerRefreshProvider.notifier).state++;
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('agro_category_saved'))));
      } catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error is FormatException
                  ? context.tr('agro_required')
                  : context.tr('error_generic'))));
      }
    }
    for (final field in fields) {
      field.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(agroOwnerRefreshProvider);
    final repository = ref.read(agroaptekaRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('agro_categories_manage'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('agro_category_add')),
      ),
      body: FutureBuilder<List<AgroCategory>>(
        future: repository.adminCategories(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorView(
                error: snapshot.error!,
                onRetry: () =>
                    ref.read(agroOwnerRefreshProvider.notifier).state++);
          if (!snapshot.hasData) return const LoadingView();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in snapshot.data!)
                ListTile(
                  title: Text(category
                      .name(Localizations.localeOf(context).languageCode)),
                  subtitle: Text(category.slug),
                  leading: Switch(
                    value: category.active,
                    onChanged: (active) async {
                      try {
                        await repository.setCategoryActive(
                            category.slug, active);
                        ref.read(agroOwnerRefreshProvider.notifier).state++;
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(context.tr('error_generic'))));
                      }
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _create(context, ref, existing: category),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final AgroStore store;
  final double? distance;
  const _StoreCard({required this.store, this.distance});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/agroapteka/store/${store.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _AgroImage(url: store.imageUrl, size: 68),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(store.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      if (store.verified)
                        const Icon(Icons.verified,
                            size: 18, color: Colors.green),
                    ]),
                    Text(
                        '${store.region}${store.district == null ? '' : ', ${store.district}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(store.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                    Wrap(spacing: 8, children: [
                      if (store.verified)
                        Text(context.tr('agro_verified'),
                            style: Theme.of(context).textTheme.labelSmall),
                      if (store.deliveryEnabled)
                        Text(context.tr('agro_delivery'),
                            style: Theme.of(context).textTheme.labelSmall),
                      if (distance != null)
                        Text(
                            '${distance!.toStringAsFixed(1)} ${context.tr('agro_distance_km')}',
                            style: Theme.of(context).textTheme.labelSmall),
                    ]),
                    if (store.openingHours?.isNotEmpty == true)
                      Text(store.openingHours!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    Text('${store.productCount} ${context.tr('agro_products')}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
              if (store.locationPublic &&
                  store.latitude != null &&
                  store.longitude != null)
                IconButton(
                  tooltip: context.tr('agro_map'),
                  icon: const Icon(Icons.map_outlined),
                  onPressed: () => _openMap(context, store),
                ),
            ]),
          ),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  final AgroProduct product;
  final VoidCallback onOpen;
  const _ProductCard({required this.product, required this.onOpen});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onOpen,
          leading: _AgroImage(url: product.imageUrl, size: 60),
          title:
              Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${product.store?.name ?? ''}\n${fmtNum(product.price)} ${product.currency} / ${product.unit} · '
              '${product.stock > 0 ? context.tr('agro_in_stock') : context.tr('agro_out_stock')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _ProductDialog extends StatelessWidget {
  final AgroProduct product;
  final VoidCallback onInquiry;
  final VoidCallback onReport;
  const _ProductDialog(
      {required this.product, required this.onInquiry, required this.onReport});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(product.title),
        content: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product.imageUrl != null)
              _AgroImage(url: product.imageUrl, size: 180),
            Text(
                '${fmtNum(product.price)} ${product.currency} / ${product.unit}',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
                '${context.tr('agro_stock')}: ${fmtNum(product.stock)} ${product.unit}'),
            if (product.store != null)
              Text('${context.tr('seller')}: ${product.store!.name}'),
            if (product.description?.isNotEmpty == true)
              Text(product.description!),
            if (product.manufacturer?.isNotEmpty == true)
              Text(
                  '${context.tr('agro_manufacturer')}: ${product.manufacturer}'),
            if (product.packageSize?.isNotEmpty == true)
              Text('${context.tr('agro_package')}: ${product.packageSize}'),
            if (product.expiryDate?.isNotEmpty == true)
              Text('${context.tr('agro_expiry')}: ${product.expiryDate}'),
            if (product.activeIngredient?.isNotEmpty == true)
              Text(
                  '${context.tr('agro_ingredient')}: ${product.activeIngredient}'),
            if (product.instructionsUrl?.isNotEmpty == true)
              Text(
                  '${context.tr('agro_instructions')}: ${product.instructionsUrl}'),
            if (product.storageConditions?.isNotEmpty == true)
              Text(
                  '${context.tr('agro_storage')}: ${product.storageConditions}'),
            if (product.safetyWarning?.isNotEmpty == true)
              Text('${context.tr('agro_safety')}: ${product.safetyWarning}'),
            const SizedBox(height: 8),
            Text(context.tr('agro_payment_unavailable'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        )),
        actions: [
          TextButton(
              onPressed: onReport, child: Text(context.tr('agro_report'))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cancel'))),
          if (product.stock > 0)
            FilledButton(
                onPressed: onInquiry, child: Text(context.tr('agro_inquiry'))),
        ],
      );
}

class _AgroImage extends StatelessWidget {
  final String? url;
  final double size;
  const _AgroImage({required this.url, required this.size});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null || url!.isEmpty
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.eco_outlined))
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.image_not_supported_outlined)),
                ),
        ),
      );
}

Future<void> _openMap(BuildContext context, AgroStore store) async {
  if (store.latitude == null || store.longitude == null) return;
  final url = Uri.https('www.openstreetmap.org', '/', {
    'mlat': '${store.latitude}',
    'mlon': '${store.longitude}',
  });
  await _launchExternal(context, url);
}

Future<void> _launchExternal(BuildContext context, Uri uri) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_generic'))),
      );
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_generic'))),
      );
  }
}

Future<void> _submitAgroReport(BuildContext context, WidgetRef ref,
    String storeId, String? productId) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('agro_report')),
      content: TextField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(labelText: ctx.tr('agro_report_reason')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.tr('send'))),
      ],
    ),
  );
  controller.dispose();
  if (reason == null) return;
  final reporterId = ref.read(sessionProvider).user?.id;
  if (reporterId == null) return;
  try {
    await ref.read(agroaptekaRepositoryProvider).submitReport(
          storeId: storeId,
          productId: productId,
          reporterId: reporterId,
          reason: reason,
        );
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('agro_report_sent'))));
  } on FormatException {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('agro_required'))));
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
  }
}

String _storeStatus(BuildContext context, String status) => context.tr({
      'approved': 'agro_status_approved',
      'pending': 'agro_status_pending',
      'rejected': 'agro_status_rejected',
      'suspended': 'agro_suspended',
    }[status] ??
    'agro_status_pending');

String _productStatus(BuildContext context, String? status) => context.tr({
      'approved': 'agro_status_approved',
      'pending': 'agro_status_pending',
      'rejected': 'agro_status_rejected_product',
      'blocked': 'agro_status_blocked',
    }[status] ??
    'agro_status_pending');

String _inquiryStatus(BuildContext context, String status) => context.tr({
      'new': 'agro_status_new',
      'reviewing': 'agro_status_reviewing',
      'accepted': 'agro_status_accepted',
      'rejected': 'agro_status_rejected',
      'completed': 'agro_status_completed',
    }[status] ??
    'agro_status_new');
