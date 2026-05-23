import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ─── Amount Display ───────────────────────────────────────────────────────────

class AmountText extends StatelessWidget {
  final double amount;
  final bool isCredit;
  final double fontSize;
  final bool showSign;

  const AmountText({
    super.key,
    required this.amount,
    this.isCredit = true,
    this.fontSize = 14,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = amount >= 0
        ? (isCredit ? AppColors.credit : AppColors.debit)
        : AppColors.debit;
    final prefix = showSign ? (amount >= 0 ? '+' : '') : '';
    return Text(
      '$prefix₹${amount.abs().toStringAsFixed(2)}',
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
    );
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color _color() => switch (status) {
        'PAID' => AppColors.success,
        'PARTIAL' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        'SENT' => AppColors.info,
        'DRAFT' => AppColors.grey500,
        'CANCELLED' => AppColors.grey400,
        _ => AppColors.grey500,
      };

  String _label() => switch (status) {
        'PAID' => 'Paid',
        'PARTIAL' => 'Partial',
        'OVERDUE' => 'Overdue',
        'SENT' => 'Sent',
        'DRAFT' => 'Draft',
        'CANCELLED' => 'Cancelled',
        _ => status,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _color().withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color().withOpacity(0.3)),
        ),
        child: Text(_label(), style: TextStyle(color: _color(), fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.grey100, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppColors.grey400),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      );
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const InfoRow(this.label, this.value, {super.key, this.valueColor, this.isBold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          )),
        ]),
      );
}

// ─── Section Header ──────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

// ─── Loading Overlay ─────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) => Stack(children: [
    child,
    if (isLoading)
      Container(
        color: Colors.black26,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
  ]);
}

// ─── Quick Action Button ─────────────────────────────────────────────────────

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ]),
            const SizedBox(height: 10),
            Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
      );
}
