import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final purchaseListProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Map<String, String>>(
  (ref, params) async {
    final storage = const FlutterSecureStorage();
    final businessId = await storage.read(key: 'business_id');
    if (businessId == null) return {'data': [], 'total': 0};
    ApiClient().setBusinessId(businessId);
    return await ApiClient().get('/v1/$businessId/purchases', params: params);
  },
);

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  String _selectedType = 'ALL';
  final _search = TextEditingController();

  final _types = ['ALL', 'PURCHASE', 'PURCHASE_RETURN', 'PURCHASE_ORDER'];
  final _typeLabels = {'ALL': 'All', 'PURCHASE': 'Bills', 'PURCHASE_RETURN': 'Returns', 'PURCHASE_ORDER': 'Orders'};

  @override
  Widget build(BuildContext context) {
    final params = <String, String>{};
    if (_selectedType != 'ALL') params['type'] = _selectedType;
    if (_search.text.isNotEmpty) params['search'] = _search.text;

    final purchasesAsync = ref.watch(purchaseListProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search bills, suppliers...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final t = _types[i];
                final selected = _selectedType == t;
                return ChoiceChip(
                  label: Text(_typeLabels[t]!),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = t),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 13),
                );
              },
            ),
          ),
          Expanded(
            child: purchasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 8),
                  Text('$e'),
                  TextButton(onPressed: () => ref.refresh(purchaseListProvider(params)), child: const Text('Retry')),
                ]),
              ),
              data: (data) {
                final bills = (data['data'] as List?) ?? [];
                if (bills.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long, size: 64, color: AppColors.grey300),
                      const SizedBox(height: 12),
                      const Text('No purchase bills found', style: TextStyle(color: AppColors.textSecondary)),
                    ]),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(purchaseListProvider(params)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: bills.length,
                    itemBuilder: (ctx, i) => _BillCard(bill: bills[i] as Map<String, dynamic>),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/purchases/create'),
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  const _BillCard({required this.bill});

  Color _statusColor(String status) => switch (status) {
        'PAID' => AppColors.success,
        'PARTIAL' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        'DRAFT' => AppColors.grey500,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final status = bill['status'] as String? ?? 'DRAFT';
    final balanceDue = (bill['balanceDue'] as num?) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/purchases/${bill['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.purchase.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.purchase, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bill['billNo'] ?? 'PUR-00001',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(bill['party']?['name'] ?? 'No Supplier',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(Formatters.date(bill['billDate'] != null ? DateTime.parse(bill['billDate']) : null),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Formatters.currency(bill['totalAmount']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(Formatters.invoiceStatus(status),
                    style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (balanceDue > 0) ...[
                const SizedBox(height: 2),
                Text('Due: ${Formatters.currency(balanceDue)}',
                    style: const TextStyle(color: AppColors.error, fontSize: 11)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
