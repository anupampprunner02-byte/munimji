import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class PartyDetail {
  final String id;
  final String name;
  final String type;
  final String? gstin;
  final String? mobile;
  final String? email;
  final double outstandingBalance;
  final String balanceType;
  final double? creditLimit;
  final int? creditDays;

  const PartyDetail({
    required this.id,
    required this.name,
    required this.type,
    this.gstin,
    this.mobile,
    this.email,
    required this.outstandingBalance,
    required this.balanceType,
    this.creditLimit,
    this.creditDays,
  });

  factory PartyDetail.fromJson(Map<String, dynamic> j) => PartyDetail(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? 'CUSTOMER',
        gstin: j['gstin']?.toString(),
        mobile: j['mobile']?.toString(),
        email: j['email']?.toString(),
        outstandingBalance:
            (j['outstandingBalance'] as num?)?.toDouble() ?? 0,
        balanceType: j['balanceType']?.toString() ?? 'DEBIT',
        creditLimit: (j['creditLimit'] as num?)?.toDouble(),
        creditDays: j['creditDays'] as int?,
      );
}

class LedgerEntry {
  final String id;
  final DateTime date;
  final String type;
  final String description;
  final double? debit;
  final double? credit;
  final double runningBalance;
  final String refId;

  const LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    this.debit,
    this.credit,
    required this.runningBalance,
    required this.refId,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id']?.toString() ?? '',
        date: j['date'] != null
            ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        type: j['type']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        debit: (j['debit'] as num?)?.toDouble(),
        credit: (j['credit'] as num?)?.toDouble(),
        runningBalance: (j['runningBalance'] as num?)?.toDouble() ?? 0,
        refId: j['refId']?.toString() ?? '',
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final partyDetailProvider =
    FutureProvider.family<PartyDetail, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  return PartyDetail.fromJson(await api.get('/api/parties/$id'));
});

final partyLedgerProvider =
    FutureProvider.family<List<LedgerEntry>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/api/parties/$id/ledger');
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

final partyInvoicesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/api/invoices',
      queryParameters: {'partyId': id, 'limit': 50});
  return (data['data'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      [];
});

final partyPaymentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final data =
      await api.get('/api/payments', queryParameters: {'partyId': id});
  return (data['data'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      [];
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PartyDetailScreen extends ConsumerStatefulWidget {
  const PartyDetailScreen({super.key, required this.partyId});

  final String partyId;

  @override
  ConsumerState<PartyDetailScreen> createState() =>
      _PartyDetailScreenState();
}

class _PartyDetailScreenState extends ConsumerState<PartyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final partyAsync = ref.watch(partyDetailProvider(widget.partyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: partyAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 56, color: AppColors.error),
                const SizedBox(height: 12),
                const Text('Failed to load party details'),
                TextButton(
                    onPressed: () =>
                        ref.invalidate(partyDetailProvider(widget.partyId)),
                    child: const Text('Retry')),
              ],
            ),
          ),
        ),
        data: (party) {
          final isCredit = party.balanceType == 'CREDIT';
          final balColor =
              isCredit ? AppColors.success : AppColors.error;

          return NestedScrollView(
            headerSliverBuilder: (ctx, inner) => [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: AppColors.primary,
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            _initials(party.name),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(party.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        if (party.gstin != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'GSTIN: ${party.gstin}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${isCredit ? 'Receivable' : 'Payable'}: ${Formatters.currency(party.outstandingBalance)}',
                            style: TextStyle(
                                color: isCredit
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFFEF9A9A),
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        context.push('/parties/${party.id}/edit'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined),
                    onPressed: () =>
                        context.push('/invoices/create',
                            extra: {'partyId': party.id}),
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Transactions'),
                    Tab(text: 'Invoices'),
                    Tab(text: 'Payments'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _LedgerTab(partyId: widget.partyId),
                _InvoicesTab(partyId: widget.partyId),
                _PaymentsTab(partyId: widget.partyId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

class _LedgerTab extends ConsumerWidget {
  const _LedgerTab({required this.partyId});

  final String partyId;

  IconData _typeIcon(String type) => switch (type) {
        'INVOICE' => Icons.receipt_outlined,
        'PAYMENT' => Icons.payments_outlined,
        'PURCHASE' => Icons.shopping_bag_outlined,
        'EXPENSE' => Icons.money_off_outlined,
        'CREDIT_NOTE' => Icons.note_outlined,
        _ => Icons.swap_horiz_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(partyLedgerProvider(partyId));

    return ledgerAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load transactions'),
            TextButton(
                onPressed: () => ref.invalidate(partyLedgerProvider(partyId)),
                child: const Text('Retry')),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: AppColors.grey300),
                SizedBox(height: 12),
                Text('No transactions yet',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final e = entries[i];
            final hasDebit = e.debit != null && e.debit! > 0;
            final hasCredit = e.credit != null && e.credit! > 0;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(e.type),
                    size: 20, color: AppColors.primary),
              ),
              title: Text(e.description,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(Formatters.date(e.date),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasDebit)
                    Text('- ${Formatters.currency(e.debit!)}',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))
                  else if (hasCredit)
                    Text('+ ${Formatters.currency(e.credit!)}',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Bal: ${Formatters.currencyCompact(e.runningBalance)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
              onTap: e.refId.isNotEmpty
                  ? () => context.push('/invoices/${e.refId}')
                  : null,
            );
          },
        );
      },
    );
  }
}

class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab({required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(partyInvoicesProvider(partyId));

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load invoices')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const Center(
            child: Text('No invoices',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: invoices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final inv = invoices[i];
            final status = inv['status']?.toString() ?? '';
            final date = inv['date'] != null
                ? DateTime.tryParse(inv['date'].toString())
                : null;
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                onTap: () =>
                    context.push('/invoices/${inv['id']}'),
                title: Text(inv['invoiceNumber']?.toString() ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: date != null
                    ? Text(Formatters.date(date),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(
                          (inv['grandTotal'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      Formatters.invoiceStatus(status),
                      style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(status),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String s) => switch (s) {
        'PAID' => AppColors.success,
        'PARTIAL' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        _ => AppColors.textSecondary,
      };
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab({required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(partyPaymentsProvider(partyId));

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load payments')),
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Text('No payments recorded',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final p = payments[i];
            final date = p['date'] != null
                ? DateTime.tryParse(p['date'].toString())
                : null;
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_outlined,
                      color: AppColors.success, size: 20),
                ),
                title: Text(
                  Formatters.paymentMode(p['mode']?.toString() ?? ''),
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
                subtitle: date != null
                    ? Text(Formatters.date(date),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))
                    : null,
                trailing: Text(
                  Formatters.currency(
                      (p['amount'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      fontSize: 14),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
