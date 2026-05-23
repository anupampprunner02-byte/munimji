import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class _ReportItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String description;

  const _ReportItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    required this.description,
  });
}

const _reports = [
  _ReportItem(
    title: 'Sales Report',
    icon: Icons.trending_up_rounded,
    color: AppColors.primary,
    route: '/reports/sales',
    description: 'Invoice-wise sales summary',
  ),
  _ReportItem(
    title: 'Purchase Report',
    icon: Icons.shopping_bag_outlined,
    color: AppColors.purchase,
    route: '/reports/purchase',
    description: 'Vendor-wise purchase summary',
  ),
  _ReportItem(
    title: 'Profit & Loss',
    icon: Icons.account_balance_outlined,
    color: AppColors.success,
    route: '/reports/profit-loss',
    description: 'Income vs expense analysis',
  ),
  _ReportItem(
    title: 'Balance Sheet',
    icon: Icons.balance_outlined,
    color: AppColors.info,
    route: '/reports/balance-sheet',
    description: 'Assets and liabilities',
  ),
  _ReportItem(
    title: 'Cash Flow',
    icon: Icons.water_drop_outlined,
    color: AppColors.accent,
    route: '/reports/cash-flow',
    description: 'Money in and money out',
  ),
  _ReportItem(
    title: 'Day Book',
    icon: Icons.menu_book_outlined,
    color: AppColors.warning,
    route: '/reports/day-book',
    description: 'Daily transaction journal',
  ),
  _ReportItem(
    title: 'Stock Summary',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF00695C),
    route: '/reports/stock',
    description: 'Current stock levels',
  ),
  _ReportItem(
    title: 'GSTR-1',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF1565C0),
    route: '/reports/gstr1',
    description: 'Outward supply returns',
  ),
  _ReportItem(
    title: 'GSTR-3B',
    icon: Icons.fact_check_outlined,
    color: Color(0xFF6A1B9A),
    route: '/reports/gstr3b',
    description: 'Monthly summary return',
  ),
  _ReportItem(
    title: 'Receivable',
    icon: Icons.arrow_downward_rounded,
    color: AppColors.success,
    route: '/reports/receivable',
    description: 'Outstanding from customers',
  ),
  _ReportItem(
    title: 'Payable',
    icon: Icons.arrow_upward_rounded,
    color: AppColors.error,
    route: '/reports/payable',
    description: 'Outstanding to vendors',
  ),
  _ReportItem(
    title: 'Expense Report',
    icon: Icons.money_off_outlined,
    color: AppColors.expense,
    route: '/reports/expenses',
    description: 'Expense category breakdown',
  ),
  _ReportItem(
    title: 'Party Statement',
    icon: Icons.people_outline,
    color: Color(0xFF00695C),
    route: '/reports/party-statement',
    description: 'Ledger per party',
  ),
  _ReportItem(
    title: 'Item Report',
    icon: Icons.inventory_outlined,
    color: Color(0xFF4527A0),
    route: '/reports/items',
    description: 'Item-wise sales & stock',
  ),
];

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () {},
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Business Reports',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          SizedBox(height: 2),
                          Text(
                            'Financial year: Apr 2024 – Mar 2025',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ReportCard(report: _reports[index]),
                childCount: _reports.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final _ReportItem report;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => context.push(report.route),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: report.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(report.icon, color: report.color, size: 24),
              ),
              const Spacer(),
              Text(
                report.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 3),
              Text(
                report.description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
