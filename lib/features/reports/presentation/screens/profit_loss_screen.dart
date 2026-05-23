import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ProfitLossData {
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double grossProfit;
  final double netProfit;
  final List<ExpenseCategory> expenseBreakdown;
  final List<MonthlySales> monthlySales;

  const ProfitLossData({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.expenseBreakdown,
    required this.monthlySales,
  });

  factory ProfitLossData.fromJson(Map<String, dynamic> j) {
    final expenses = (j['expenseBreakdown'] as List<dynamic>?)
            ?.map((e) =>
                ExpenseCategory.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final monthly = (j['monthlySales'] as List<dynamic>?)
            ?.map((e) =>
                MonthlySales.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ProfitLossData(
      totalSales: (j['totalSales'] as num?)?.toDouble() ?? 0,
      totalPurchases: (j['totalPurchases'] as num?)?.toDouble() ?? 0,
      totalExpenses: (j['totalExpenses'] as num?)?.toDouble() ?? 0,
      grossProfit: (j['grossProfit'] as num?)?.toDouble() ?? 0,
      netProfit: (j['netProfit'] as num?)?.toDouble() ?? 0,
      expenseBreakdown: expenses,
      monthlySales: monthly,
    );
  }
}

class ExpenseCategory {
  final String category;
  final double amount;

  const ExpenseCategory({required this.category, required this.amount});

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) =>
      ExpenseCategory(
        category: j['category']?.toString() ?? 'Other',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

class MonthlySales {
  final String month;
  final double sales;
  final double purchases;

  const MonthlySales(
      {required this.month,
      required this.sales,
      required this.purchases});

  factory MonthlySales.fromJson(Map<String, dynamic> j) => MonthlySales(
        month: j['month']?.toString() ?? '',
        sales: (j['sales'] as num?)?.toDouble() ?? 0,
        purchases: (j['purchases'] as num?)?.toDouble() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _plDateRangeProvider =
    StateProvider<(DateTime, DateTime)>((ref) {
  final now = DateTime.now();
  final fyStart = now.month >= 4
      ? DateTime(now.year, 4, 1)
      : DateTime(now.year - 1, 4, 1);
  final fyEnd = fyStart.month == 4
      ? DateTime(fyStart.year + 1, 3, 31)
      : DateTime(fyStart.year, 3, 31);
  return (fyStart, fyEnd);
});

final _plSelectedYearProvider = StateProvider<String>((ref) => 'FY 2024-25');

final profitLossProvider =
    FutureProvider.autoDispose<ProfitLossData>((ref) async {
  final (from, to) = ref.watch(_plDateRangeProvider);
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/api/reports/profit-loss', queryParameters: {
    'from': Formatters.isoDate(from),
    'to': Formatters.isoDate(to),
  });
  return ProfitLossData.fromJson(resp.data as Map<String, dynamic>);
});

// Placeholder data for charts when API fails or loading
ProfitLossData _placeholderData() {
  return ProfitLossData(
    totalSales: 1250000,
    totalPurchases: 780000,
    totalExpenses: 180000,
    grossProfit: 470000,
    netProfit: 290000,
    expenseBreakdown: const [
      ExpenseCategory(category: 'Rent', amount: 60000),
      ExpenseCategory(category: 'Salaries', amount: 80000),
      ExpenseCategory(category: 'Utilities', amount: 12000),
      ExpenseCategory(category: 'Marketing', amount: 18000),
      ExpenseCategory(category: 'Other', amount: 10000),
    ],
    monthlySales: [
      MonthlySales(month: 'Apr', sales: 95000, purchases: 60000),
      MonthlySales(month: 'May', sales: 102000, purchases: 65000),
      MonthlySales(month: 'Jun', sales: 88000, purchases: 55000),
      MonthlySales(month: 'Jul', sales: 115000, purchases: 72000),
      MonthlySales(month: 'Aug', sales: 108000, purchases: 68000),
      MonthlySales(month: 'Sep', sales: 125000, purchases: 78000),
      MonthlySales(month: 'Oct', sales: 132000, purchases: 82000),
      MonthlySales(month: 'Nov', sales: 98000, purchases: 61000),
      MonthlySales(month: 'Dec', sales: 145000, purchases: 90000),
      MonthlySales(month: 'Jan', sales: 88000, purchases: 55000),
      MonthlySales(month: 'Feb', sales: 78000, purchases: 48000),
      MonthlySales(month: 'Mar', sales: 76000, purchases: 46000),
    ],
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  int _touchedExpenseIndex = -1;

  @override
  Widget build(BuildContext context) {
    final plAsync = ref.watch(profitLossProvider);
    final (fromDate, toDate) = ref.watch(_plDateRangeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profit & Loss',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
            tooltip: 'Export',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _DateRangeChip(
                    label: DateFormat('dd MMM yyyy').format(fromDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickFromDate(context, fromDate, toDate),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child:
                      Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
                ),
                Expanded(
                  child: _DateRangeChip(
                    label: DateFormat('dd MMM yyyy').format(toDate),
                    icon: Icons.event_outlined,
                    onTap: () => _pickToDate(context, fromDate, toDate),
                  ),
                ),
                const SizedBox(width: 8),
                _FyDropdown(
                  value: ref.watch(_plSelectedYearProvider),
                  onChanged: (v) {
                    ref.read(_plSelectedYearProvider.notifier).state = v;
                    _setFyDates(v, ref);
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: plAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) {
                // Show placeholder data on error
                final data = _placeholderData();
                return _ProfitLossBody(
                  data: data,
                  touchedIndex: _touchedExpenseIndex,
                  onTouchExpense: (i) =>
                      setState(() => _touchedExpenseIndex = i),
                  isPlaceholder: true,
                );
              },
              data: (data) => _ProfitLossBody(
                data: data,
                touchedIndex: _touchedExpenseIndex,
                onTouchExpense: (i) =>
                    setState(() => _touchedExpenseIndex = i),
                isPlaceholder: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromDate(
      BuildContext context, DateTime from, DateTime to) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(2020),
      lastDate: to,
    );
    if (picked != null) {
      ref.read(_plDateRangeProvider.notifier).state = (picked, to);
      ref.invalidate(profitLossProvider);
    }
  }

  Future<void> _pickToDate(
      BuildContext context, DateTime from, DateTime to) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: to,
      firstDate: from,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ref.read(_plDateRangeProvider.notifier).state = (from, picked);
      ref.invalidate(profitLossProvider);
    }
  }

  void _setFyDates(String fy, WidgetRef ref) {
    final parts = fy.replaceAll('FY ', '').split('-');
    if (parts.length < 2) return;
    final year = int.tryParse(parts[0]);
    if (year == null) return;
    final from = DateTime(year, 4, 1);
    final to = DateTime(year + 1, 3, 31);
    ref.read(_plDateRangeProvider.notifier).state = (from, to);
    ref.invalidate(profitLossProvider);
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ProfitLossBody extends StatelessWidget {
  const _ProfitLossBody({
    required this.data,
    required this.touchedIndex,
    required this.onTouchExpense,
    required this.isPlaceholder,
  });

  final ProfitLossData data;
  final int touchedIndex;
  final void Function(int) onTouchExpense;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (isPlaceholder)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing sample data. Connect to server to see real figures.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Sales',
                  amount: data.totalSales,
                  color: AppColors.primary,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: 'Total Purchases',
                  amount: data.totalPurchases,
                  color: AppColors.purchase,
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Expenses',
                  amount: data.totalExpenses,
                  color: AppColors.expense,
                  icon: Icons.money_off_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: 'Gross Profit',
                  amount: data.grossProfit,
                  color: AppColors.success,
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: data.netProfit >= 0
                    ? [
                        AppColors.success.withOpacity(0.15),
                        AppColors.success.withOpacity(0.05),
                      ]
                    : [
                        AppColors.error.withOpacity(0.15),
                        AppColors.error.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: (data.netProfit >= 0
                          ? AppColors.success
                          : AppColors.error)
                      .withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  data.netProfit >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 32,
                  color: data.netProfit >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Profit',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                    Text(
                      Formatters.currency(data.netProfit),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: data.netProfit >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Expense Breakdown (Horizontal Bar Chart)
          if (data.expenseBreakdown.isNotEmpty) ...[
            _ChartCard(
              title: 'Expense Breakdown',
              subtitle: 'By category',
              child: _ExpenseBarChart(
                categories: data.expenseBreakdown,
                touchedIndex: touchedIndex,
                onTouch: onTouchExpense,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Monthly Sales Trend (Line Chart)
          if (data.monthlySales.isNotEmpty) ...[
            _ChartCard(
              title: 'Monthly Trend',
              subtitle: 'Sales vs Purchases',
              child: _MonthlyLineChart(monthlyData: data.monthlySales),
            ),
            const SizedBox(height: 16),
          ],

          // Detailed Breakdown Table
          _DetailCard(data: data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart Widgets
// ---------------------------------------------------------------------------

class _ExpenseBarChart extends StatelessWidget {
  const _ExpenseBarChart({
    required this.categories,
    required this.touchedIndex,
    required this.onTouch,
  });

  final List<ExpenseCategory> categories;
  final int touchedIndex;
  final void Function(int) onTouch;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final maxAmount = categories
        .map((e) => e.amount)
        .reduce((a, b) => a > b ? a : b);

    const barColors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.warning,
      AppColors.expense,
      AppColors.error,
      Color(0xFF6A1B9A),
    ];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.85),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final cat = categories[groupIndex];
                return BarTooltipItem(
                  '${cat.category}\n${Formatters.currency(cat.amount)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
            touchCallback: (event, response) {
              if (response?.spot?.touchedBarGroupIndex != null) {
                onTouch(response!.spot!.touchedBarGroupIndex);
              } else {
                onTouch(-1);
              }
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= categories.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      categories[idx]
                          .category
                          .split(' ')
                          .first
                          .substring(
                              0,
                              categories[idx].category.length > 6
                                  ? 6
                                  : categories[idx].category.length),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) => Text(
                  Formatters.currencyCompact(value),
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: AppColors.grey200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: categories.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value;
            final isTouched = i == touchedIndex;
            final color = barColors[i % barColors.length];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: cat.amount,
                  color:
                      isTouched ? color : color.withOpacity(0.75),
                  width: isTouched ? 22 : 18,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MonthlyLineChart extends StatelessWidget {
  const _MonthlyLineChart({required this.monthlyData});

  final List<MonthlySales> monthlyData;

  @override
  Widget build(BuildContext context) {
    if (monthlyData.isEmpty) return const SizedBox.shrink();

    final maxSale = monthlyData
        .map((e) => e.sales)
        .reduce((a, b) => a > b ? a : b);
    final maxPurchase = monthlyData
        .map((e) => e.purchases)
        .reduce((a, b) => a > b ? a : b);
    final maxY = (maxSale > maxPurchase ? maxSale : maxPurchase) * 1.2;

    final salesSpots = monthlyData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.sales))
        .toList();

    final purchaseSpots = monthlyData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.purchases))
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (monthlyData.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      AppColors.textPrimary.withOpacity(0.85),
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.x.toInt();
                    final month = idx < monthlyData.length
                        ? monthlyData[idx].month
                        : '';
                    final label = s.barIndex == 0 ? 'Sales' : 'Purchase';
                    return LineTooltipItem(
                      '$month $label\n${Formatters.currencyCompact(s.y)}',
                      const TextStyle(
                          color: Colors.white, fontSize: 10),
                    );
                  }).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= monthlyData.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          monthlyData[idx].month,
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, meta) => Text(
                      Formatters.currencyCompact(value),
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.grey200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Sales line
                LineChartBarData(
                  spots: salesSpots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                ),
                // Purchase line
                LineChartBarData(
                  spots: purchaseSpots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.purchase,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.purchase.withOpacity(0.06),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.primary, label: 'Sales'),
            const SizedBox(width: 20),
            _LegendDot(
                color: AppColors.purchase, label: 'Purchases'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting Widgets
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(Formatters.currencyCompact(amount),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.data});

  final ProfitLossData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detailed Breakdown',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          _Row('Total Sales Revenue', data.totalSales,
              color: AppColors.primary),
          _Row('Less: Cost of Purchases', -data.totalPurchases,
              color: AppColors.error),
          const Divider(height: 16),
          _Row('Gross Profit', data.grossProfit,
              color: AppColors.success, bold: true),
          const SizedBox(height: 8),
          const Text('Less: Operating Expenses',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...data.expenseBreakdown.map((e) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _Row(e.category, -e.amount),
              )),
          const Divider(height: 16),
          _Row('Net Profit / Loss', data.netProfit,
              color: data.netProfit >= 0
                  ? AppColors.success
                  : AppColors.error,
              bold: true,
              large: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.amount,
      {this.color, this.bold = false, this.large = false});

  final String label;
  final double amount;
  final Color? color;
  final bool bold;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: large ? 14 : 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.normal,
                  color: large
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                )),
          ),
          Text(
            '${amount < 0 ? '- ' : ''}${Formatters.currency(amount.abs())}',
            style: TextStyle(
              fontSize: large ? 14 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auxiliary Widgets for AppBar area
// ---------------------------------------------------------------------------

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _FyDropdown extends StatelessWidget {
  const _FyDropdown({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    const fyList = [
      'FY 2024-25',
      'FY 2023-24',
      'FY 2022-23',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: AppColors.primaryDark,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Colors.white, fontSize: 11),
        icon: const Icon(Icons.expand_more, color: Colors.white70, size: 16),
        items: fyList
            .map((fy) =>
                DropdownMenuItem(value: fy, child: Text(fy)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
