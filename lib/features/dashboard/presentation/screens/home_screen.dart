import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _DashboardSummary {
  final double todaySale;
  final double monthSale;
  final double totalReceivable;
  final double totalPayable;

  const _DashboardSummary({
    required this.todaySale,
    required this.monthSale,
    required this.totalReceivable,
    required this.totalPayable,
  });

  factory _DashboardSummary.fromJson(Map<String, dynamic> j) =>
      _DashboardSummary(
        todaySale: (j['todaySale'] as num?)?.toDouble() ?? 0,
        monthSale: (j['monthSale'] as num?)?.toDouble() ?? 0,
        totalReceivable: (j['totalReceivable'] as num?)?.toDouble() ?? 0,
        totalPayable: (j['totalPayable'] as num?)?.toDouble() ?? 0,
      );
}

class _RecentInvoice {
  final String id;
  final String invoiceNumber;
  final String partyName;
  final DateTime date;
  final double grandTotal;
  final double balanceDue;
  final String status;

  const _RecentInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.partyName,
    required this.date,
    required this.grandTotal,
    required this.balanceDue,
    required this.status,
  });

  factory _RecentInvoice.fromJson(Map<String, dynamic> j) => _RecentInvoice(
        id: j['id']?.toString() ?? '',
        invoiceNumber: j['invoiceNumber']?.toString() ?? '',
        partyName: j['party']?['name']?.toString() ?? '-',
        date: j['date'] != null
            ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
        balanceDue: (j['balanceDue'] as num?)?.toDouble() ?? 0,
        status: j['status']?.toString() ?? 'DRAFT',
      );
}

class _LowStockItem {
  final String name;
  final double stock;
  final String unit;

  const _LowStockItem(
      {required this.name, required this.stock, required this.unit});
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _dashboardSummaryProvider =
    FutureProvider<_DashboardSummary>((ref) async {
  final api = ref.read(apiClientProvider);
  return _DashboardSummary.fromJson(await api.get('/api/dashboard/summary'));
});

final _recentInvoicesProvider =
    FutureProvider<List<_RecentInvoice>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/api/invoices', queryParameters: {
    'limit': 5,
    'sortBy': 'date',
    'order': 'desc',
  });
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => _RecentInvoice.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  return await api.get('/api/auth/me');
});

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;

  final _tabs = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Sales',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'Purchase',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Inventory',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz),
      selectedIcon: Icon(Icons.more_horiz),
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _HomeTab(onTabChange: (i) => setState(() => _selectedTab = i)),
          _SalesTab(),
          _PurchaseTab(),
          _InventoryTab(),
          _MoreTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: _tabs,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home Tab
// ---------------------------------------------------------------------------

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.onTabChange});

  final void Function(int) onTabChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_dashboardSummaryProvider);
    final recentAsync = ref.watch(_recentInvoicesProvider);
    final profileAsync = ref.watch(_profileProvider);

    final userName = profileAsync.maybeWhen(
      data: (d) => d['name']?.toString() ?? 'User',
      orElse: () => 'User',
    );
    final bizName = profileAsync.maybeWhen(
      data: (d) {
        final biz = d['currentBusiness'] as Map<String, dynamic>?;
        return biz?['name']?.toString() ?? '';
      },
      orElse: () => '',
    );

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardSummaryProvider);
          ref.invalidate(_recentInvoicesProvider);
          ref.invalidate(_profileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            // Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $userName',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                        if (bizName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(bizName,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: summaryAsync.when(
                loading: () => const _SummaryCardsShimmer(),
                error: (_, __) => const _SummaryCardsError(),
                data: (s) => GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  children: [
                    _SummaryCard(
                      title: "Today's Sale",
                      amount: s.todaySale,
                      icon: Icons.today_outlined,
                      iconColor: AppColors.primary,
                      subtitle: 'vs yesterday',
                    ),
                    _SummaryCard(
                      title: 'Month Sale',
                      amount: s.monthSale,
                      icon: Icons.calendar_month_outlined,
                      iconColor: AppColors.accent,
                      subtitle: 'this month',
                    ),
                    _SummaryCard(
                      title: 'Receivable',
                      amount: s.totalReceivable,
                      icon: Icons.arrow_downward_rounded,
                      iconColor: AppColors.success,
                      subtitle: 'to collect',
                    ),
                    _SummaryCard(
                      title: 'Payable',
                      amount: s.totalPayable,
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.error,
                      subtitle: 'to pay',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Actions',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QuickAction(
                          icon: Icons.receipt_long,
                          label: 'Invoice',
                          color: AppColors.primary,
                          onTap: () => context.push('/invoices/create')),
                      _QuickAction(
                          icon: Icons.payments_outlined,
                          label: 'Payment In',
                          color: AppColors.success,
                          onTap: () => context.push('/payments/in/create')),
                      _QuickAction(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Purchase',
                          color: AppColors.purchase,
                          onTap: () => context.push('/purchase/create')),
                      _QuickAction(
                          icon: Icons.money_off_outlined,
                          label: 'Expense',
                          color: AppColors.expense,
                          onTap: () => context.push('/expenses/create')),
                      _QuickAction(
                          icon: Icons.inventory_2_outlined,
                          label: 'Item',
                          color: AppColors.accent,
                          onTap: () => context.push('/items/add')),
                      _QuickAction(
                          icon: Icons.people_outline,
                          label: 'Party',
                          color: AppColors.warning,
                          onTap: () => context.push('/parties/add')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recent Transactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Transactions',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () => context.push('/invoices'),
                    child: const Text('View All',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),

            recentAsync.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator())),
              error: (_, __) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                      child: Text('Failed to load transactions',
                          style: TextStyle(color: AppColors.textSecondary)))),
              data: (invoices) {
                if (invoices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No recent transactions',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _RecentInvoiceTile(invoice: invoices[i]),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.subtitle,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color iconColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            Formatters.currencyCompact(amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentInvoiceTile extends StatelessWidget {
  const _RecentInvoiceTile({required this.invoice});

  final _RecentInvoice invoice;

  Color _statusColor(String s) => switch (s) {
        'PAID' => AppColors.success,
        'PARTIAL' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        'SENT' => AppColors.info,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.receipt_outlined,
            color: AppColors.primary, size: 22),
      ),
      title: Text(invoice.partyName,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary)),
      subtitle: Text('${invoice.invoiceNumber} • ${Formatters.date(invoice.date)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Formatters.currency(invoice.grandTotal),
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(invoice.status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              Formatters.invoiceStatus(invoice.status),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _statusColor(invoice.status),
              ),
            ),
          ),
        ],
      ),
      onTap: () => context.push('/invoices/${invoice.id}'),
    );
  }
}

class _SummaryCardsShimmer extends StatelessWidget {
  const _SummaryCardsShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      children: List.generate(
          4,
          (_) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              )),
    );
  }
}

class _SummaryCardsError extends StatelessWidget {
  const _SummaryCardsError();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(
        child: Text('Failed to load summary',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stub tab bodies (navigation placeholders)
// ---------------------------------------------------------------------------

class _SalesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.push('/invoices'));
    return const SizedBox.shrink();
  }
}

class _PurchaseTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.push('/purchases'));
    return const SizedBox.shrink();
  }
}

class _InventoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.push('/items'));
    return const SizedBox.shrink();
  }
}

class _MoreTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text('More',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          _MoreTile(
            icon: Icons.people_outline,
            label: 'Parties',
            onTap: () => context.push('/parties'),
          ),
          _MoreTile(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: () => context.push('/reports'),
          ),
          _MoreTile(
            icon: Icons.receipt_outlined,
            label: 'Expenses',
            onTap: () => context.push('/expenses'),
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.push('/settings'),
          ),
          _MoreTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () => context.push('/help'),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
