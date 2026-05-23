import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class InvoiceSummary {
  final String id;
  final String invoiceNumber;
  final String partyName;
  final DateTime date;
  final double grandTotal;
  final double balanceDue;
  final String status;
  final String type;

  const InvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.partyName,
    required this.date,
    required this.grandTotal,
    required this.balanceDue,
    required this.status,
    required this.type,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> j) => InvoiceSummary(
        id: j['id']?.toString() ?? '',
        invoiceNumber: j['invoiceNumber']?.toString() ?? '',
        partyName: j['party']?['name']?.toString() ?? '-',
        date: j['date'] != null
            ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
        balanceDue: (j['balanceDue'] as num?)?.toDouble() ?? 0,
        status: j['status']?.toString() ?? 'DRAFT',
        type: j['type']?.toString() ?? 'SALE',
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _invoiceFilterProvider = StateProvider<String>((ref) => 'ALL');
final _invoiceSearchProvider = StateProvider<String>((ref) => '');

final invoiceListProvider =
    FutureProvider.family<List<InvoiceSummary>, String>((ref, filter) async {
  final api = ref.read(apiClientProvider);
  final search = ref.read(_invoiceSearchProvider);
  final params = <String, dynamic>{
    'limit': 50,
    'sortBy': 'date',
    'order': 'desc',
    if (filter != 'ALL') 'status': filter,
    if (search.isNotEmpty) 'search': search,
  };
  final data = await api.get('/api/invoices', queryParameters: params);
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => InvoiceSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _searchCtrl = TextEditingController();

  static const _filters = [
    ('ALL', 'All'),
    ('DRAFT', 'Draft'),
    ('SENT', 'Sent'),
    ('PAID', 'Paid'),
    ('PARTIAL', 'Partial'),
    ('OVERDUE', 'Overdue'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(_invoiceFilterProvider);
    final invoicesAsync = ref.watch(invoiceListProvider(activeFilter));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoices',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search by party name or invoice no…',
              leading: const Icon(Icons.search, color: AppColors.textSecondary),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(_invoiceSearchProvider.notifier).state = '';
                      ref.invalidate(invoiceListProvider(activeFilter));
                    },
                  ),
              ],
              backgroundColor:
                  WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.all(0),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) {
                ref.read(_invoiceSearchProvider.notifier).state = v;
                ref.invalidate(invoiceListProvider(activeFilter));
              },
            ),
          ),

          // Filter Chips
          Container(
            color: Colors.white,
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (code, label) = _filters[i];
                final selected = activeFilter == code;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(_invoiceFilterProvider.notifier).state = code;
                  },
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.grey300),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),

          // List
          Expanded(
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorView(
                  onRetry: () =>
                      ref.invalidate(invoiceListProvider(activeFilter))),
              data: (invoices) {
                if (invoices.isEmpty) {
                  return _EmptyView(onCreateTap: () =>
                      context.push('/invoices/create'));
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(invoiceListProvider(activeFilter)),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        InvoiceCard(invoice: invoices[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/invoices/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort & Filter',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            const Text('More filter options coming soon.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invoice Card
// ---------------------------------------------------------------------------

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.invoice});

  final InvoiceSummary invoice;

  static Color statusColor(String s) => switch (s) {
        'PAID' => AppColors.success,
        'PARTIAL' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        'SENT' => AppColors.info,
        'CANCELLED' => AppColors.grey500,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final color = statusColor(invoice.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/invoices/${invoice.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invoice.partyName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(invoice.invoiceNumber,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Formatters.currency(invoice.grandTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          Formatters.invoiceStatus(invoice.status),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(Formatters.date(invoice.date),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  if (invoice.balanceDue > 0) ...[
                    const Text('Due: ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text(Formatters.currency(invoice.balanceDue),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Failed to load invoices',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 72, color: AppColors.grey300),
          const SizedBox(height: 16),
          const Text('No Invoices Yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Create your first invoice to get started',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('Create Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
