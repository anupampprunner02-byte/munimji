import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ItemSummary {
  final String id;
  final String name;
  final String? code;
  final String? category;
  final double currentStock;
  final double? lowStockAlert;
  final String unit;
  final double salePrice;
  final double? purchasePrice;
  final double taxRate;
  final bool isService;

  const ItemSummary({
    required this.id,
    required this.name,
    this.code,
    this.category,
    required this.currentStock,
    this.lowStockAlert,
    required this.unit,
    required this.salePrice,
    this.purchasePrice,
    required this.taxRate,
    required this.isService,
  });

  bool get isLowStock =>
      !isService &&
      lowStockAlert != null &&
      currentStock <= lowStockAlert!;

  factory ItemSummary.fromJson(Map<String, dynamic> j) => ItemSummary(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        code: j['code']?.toString(),
        category: j['category']?.toString(),
        currentStock: (j['currentStock'] as num?)?.toDouble() ?? 0,
        lowStockAlert: (j['lowStockAlert'] as num?)?.toDouble(),
        unit: j['unit']?.toString() ?? 'PCS',
        salePrice: (j['salePrice'] as num?)?.toDouble() ?? 0,
        purchasePrice: (j['purchasePrice'] as num?)?.toDouble(),
        taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0,
        isService: j['isService'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _itemCategoryFilterProvider = StateProvider<String?>((ref) => null);
final _itemSearchQueryProvider = StateProvider<String>((ref) => '');

final itemCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.read(apiClientProvider);
  final resp =
      await api.get('/api/items/categories');
  final data = resp.data as Map<String, dynamic>;
  return ((data['data'] as List<dynamic>?) ?? [])
      .map((e) => e.toString())
      .toList();
});

final itemListProvider = FutureProvider<List<ItemSummary>>((ref) async {
  final api = ref.read(apiClientProvider);
  final category = ref.watch(_itemCategoryFilterProvider);
  final search = ref.watch(_itemSearchQueryProvider);
  final params = <String, dynamic>{
    'limit': 100,
    'sortBy': 'name',
    if (category != null) 'category': category,
    if (search.isNotEmpty) 'search': search,
  };
  final resp = await api.get('/api/items', queryParameters: params);
  final data = resp.data as Map<String, dynamic>;
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => ItemSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider);
    final categoriesAsync = ref.watch(itemCategoriesProvider);
    final selectedCategory = ref.watch(_itemCategoryFilterProvider);

    final lowStockItems = itemsAsync.maybeWhen(
      data: (items) => items.where((i) => i.isLowStock).toList(),
      orElse: () => <ItemSummary>[],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search items by name or code…',
              leading: const Icon(Icons.search, color: AppColors.textSecondary),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(_itemSearchQueryProvider.notifier).state = '';
                      ref.invalidate(itemListProvider);
                    },
                  ),
              ],
              backgroundColor: WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.all(0),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
              onChanged: (v) {
                ref.read(_itemSearchQueryProvider.notifier).state = v;
                ref.invalidate(itemListProvider);
              },
            ),
          ),

          // Category filter chips
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) => categories.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.white,
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: selectedCategory == null,
                            onSelected: (_) {
                              ref
                                  .read(_itemCategoryFilterProvider.notifier)
                                  .state = null;
                              ref.invalidate(itemListProvider);
                            },
                            selectedColor:
                                AppColors.primary.withOpacity(0.15),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selectedCategory == null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: selectedCategory == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                                color: selectedCategory == null
                                    ? AppColors.primary
                                    : AppColors.grey300),
                          ),
                        ),
                        ...categories.map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat),
                                selected: selectedCategory == cat,
                                onSelected: (_) {
                                  ref
                                      .read(_itemCategoryFilterProvider
                                          .notifier)
                                      .state = cat;
                                  ref.invalidate(itemListProvider);
                                },
                                selectedColor:
                                    AppColors.primary.withOpacity(0.15),
                                checkmarkColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: selectedCategory == cat
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: selectedCategory == cat
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                    color: selectedCategory == cat
                                        ? AppColors.primary
                                        : AppColors.grey300),
                              ),
                            )),
                      ],
                    ),
                  ),
          ),

          // Low stock banner
          if (lowStockItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${lowStockItems.length} item${lowStockItems.length > 1 ? 's are' : ' is'} running low on stock',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Item List
          Expanded(
            child: itemsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('Failed to load items'),
                    TextButton(
                        onPressed: () => ref.invalidate(itemListProvider),
                        child: const Text('Retry')),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 72, color: AppColors.grey300),
                        const SizedBox(height: 16),
                        const Text('No Items Found',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text('Add your products and services',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/items/add'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(itemListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => ItemCard(item: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/items/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item Card
// ---------------------------------------------------------------------------

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item});

  final ItemSummary item;

  @override
  Widget build(BuildContext context) {
    final stockColor = item.isService
        ? AppColors.info
        : item.isLowStock
            ? AppColors.error
            : item.currentStock == 0
                ? AppColors.error
                : AppColors.success;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/items/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isService
                      ? Icons.miscellaneous_services_outlined
                      : Icons.inventory_2_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.code != null && item.code!.isNotEmpty) ...[
                          Text(item.code!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const Text(' • ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                        if (item.category != null)
                          Text(item.category!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.currency(item.salePrice),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  if (!item.isService)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isLowStock)
                          const Icon(Icons.warning_amber_rounded,
                              size: 12, color: AppColors.warning),
                        const SizedBox(width: 2),
                        Text(
                          '${Formatters.quantity(item.currentStock)} ${item.unit}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: stockColor),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Service',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.info,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
