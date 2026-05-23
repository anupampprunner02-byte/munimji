import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class InvoiceDetail {
  final String id;
  final String invoiceNumber;
  final DateTime date;
  final DateTime? dueDate;
  final String status;
  final String type;
  final String partyName;
  final String? partyGstin;
  final String? partyAddress;
  final String? partyMobile;
  final List<InvoiceLineItem> items;
  final double subtotal;
  final double totalDiscount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double grandTotal;
  final double balanceDue;
  final List<PaymentRecord> payments;
  final String? notes;
  final String? terms;

  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.dueDate,
    required this.status,
    required this.type,
    required this.partyName,
    this.partyGstin,
    this.partyAddress,
    this.partyMobile,
    required this.items,
    required this.subtotal,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.grandTotal,
    required this.balanceDue,
    required this.payments,
    this.notes,
    this.terms,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>? ?? {};
    final itemsList = j['items'] as List<dynamic>? ?? [];
    final payList = j['payments'] as List<dynamic>? ?? [];

    return InvoiceDetail(
      id: j['id']?.toString() ?? '',
      invoiceNumber: j['invoiceNumber']?.toString() ?? '',
      date: j['date'] != null
          ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: j['dueDate'] != null
          ? DateTime.tryParse(j['dueDate'].toString())
          : null,
      status: j['status']?.toString() ?? 'DRAFT',
      type: j['type']?.toString() ?? 'SALE',
      partyName: party['name']?.toString() ?? '-',
      partyGstin: party['gstin']?.toString(),
      partyAddress: party['address']?.toString(),
      partyMobile: party['mobile']?.toString(),
      items: itemsList
          .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
      totalDiscount: (j['totalDiscount'] as num?)?.toDouble() ?? 0,
      taxableAmount: (j['taxableAmount'] as num?)?.toDouble() ?? 0,
      cgst: (j['cgst'] as num?)?.toDouble() ?? 0,
      sgst: (j['sgst'] as num?)?.toDouble() ?? 0,
      igst: (j['igst'] as num?)?.toDouble() ?? 0,
      grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
      balanceDue: (j['balanceDue'] as num?)?.toDouble() ?? 0,
      payments: payList
          .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: j['notes']?.toString(),
      terms: j['terms']?.toString(),
    );
  }
}

class InvoiceLineItem {
  final String name;
  final String? hsn;
  final double quantity;
  final String unit;
  final double rate;
  final double discountPercent;
  final double taxRate;
  final double amount;

  const InvoiceLineItem({
    required this.name,
    this.hsn,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.discountPercent,
    required this.taxRate,
    required this.amount,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> j) {
    final item = j['item'] as Map<String, dynamic>? ?? {};
    return InvoiceLineItem(
      name: item['name']?.toString() ?? j['name']?.toString() ?? '',
      hsn: item['hsnCode']?.toString(),
      quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
      unit: item['unit']?.toString() ?? 'PCS',
      rate: (j['rate'] as num?)?.toDouble() ?? 0,
      discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0,
      taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaymentRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String mode;

  const PaymentRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.mode,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> j) => PaymentRecord(
        id: j['id']?.toString() ?? '',
        date: j['date'] != null
            ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        mode: j['mode']?.toString() ?? 'CASH',
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final invoiceDetailProvider =
    FutureProvider.family<InvoiceDetail, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/api/invoices/$id');
  return InvoiceDetail.fromJson(resp.data as Map<String, dynamic>);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          invoiceAsync.when(
            data: (inv) => PopupMenuButton<String>(
              onSelected: (v) =>
                  _handleAction(context, ref, v, inv),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'share_whatsapp', child: Text('Share on WhatsApp')),
                PopupMenuItem(value: 'share_pdf', child: Text('Share PDF')),
                PopupMenuItem(value: 'print', child: Text('Print')),
                PopupMenuItem(value: 'download', child: Text('Download PDF')),
              ],
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.share_outlined, color: Colors.white)),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Failed to load invoice'),
              TextButton(
                  onPressed: () =>
                      ref.invalidate(invoiceDetailProvider(invoiceId)),
                  child: const Text('Retry')),
            ],
          ),
        ),
        data: (inv) => _InvoiceDetailBody(
          invoice: inv,
          onEdit: () => context.push('/invoices/${inv.id}/edit'),
          onRecordPayment: () =>
              _showRecordPaymentSheet(context, ref, inv),
          onCancel: () => _cancelInvoice(context, ref, inv.id),
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action, InvoiceDetail inv) async {
    switch (action) {
      case 'share_whatsapp':
        final num = inv.partyMobile ?? '';
        final msg = Uri.encodeComponent(
            'Hello ${inv.partyName}, please find your invoice ${inv.invoiceNumber} '
            'for ${Formatters.currency(inv.grandTotal)} dated ${Formatters.date(inv.date)}. '
            'Balance due: ${Formatters.currency(inv.balanceDue)}');
        final url = 'https://wa.me/91$num?text=$msg';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        }
        break;
      case 'share_pdf':
      case 'download':
        final pdfData = await _buildPdf(inv);
        final dir = await getTemporaryDirectory();
        final file =
            File('${dir.path}/invoice_${inv.invoiceNumber}.pdf');
        await file.writeAsBytes(pdfData);
        await Share.shareXFiles([XFile(file.path)],
            text: 'Invoice ${inv.invoiceNumber}');
        break;
      case 'print':
        final pdfData = await _buildPdf(inv);
        await Printing.layoutPdf(onLayout: (_) async => pdfData);
        break;
    }
  }

  Future<List<int>> _buildPdf(InvoiceDetail inv) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TAX INVOICE',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Invoice No: ${inv.invoiceNumber}',
                        style:
                            pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${Formatters.date(inv.date)}'),
                    if (inv.dueDate != null)
                      pw.Text('Due: ${Formatters.date(inv.dueDate)}'),
                  ],
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('Bill To:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(inv.partyName),
            if (inv.partyGstin != null)
              pw.Text('GSTIN: ${inv.partyGstin}'),
            if (inv.partyAddress != null) pw.Text(inv.partyAddress!),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Item', 'HSN', 'Qty', 'Rate', 'Disc%', 'GST%', 'Amount'],
              data: inv.items
                  .map((i) => [
                        i.name,
                        i.hsn ?? '',
                        Formatters.quantity(i.quantity, unit: i.unit),
                        Formatters.currency(i.rate),
                        '${i.discountPercent}%',
                        '${i.taxRate}%',
                        Formatters.currency(i.amount),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                6: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Subtotal: ${Formatters.currency(inv.subtotal)}'),
                  pw.Text(
                      'Discount: -${Formatters.currency(inv.totalDiscount)}'),
                  pw.Text(
                      'Taxable: ${Formatters.currency(inv.taxableAmount)}'),
                  if (inv.igst > 0)
                    pw.Text('IGST: ${Formatters.currency(inv.igst)}')
                  else ...[
                    pw.Text('CGST: ${Formatters.currency(inv.cgst)}'),
                    pw.Text('SGST: ${Formatters.currency(inv.sgst)}'),
                  ],
                  pw.Divider(),
                  pw.Text('Grand Total: ${Formatters.currency(inv.grandTotal)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            if (inv.notes != null && inv.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Notes: ${inv.notes}',
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic, fontSize: 11)),
            ],
            if (inv.terms != null && inv.terms!.isNotEmpty)
              pw.Text('Terms: ${inv.terms}',
                  style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  void _showRecordPaymentSheet(
      BuildContext context, WidgetRef ref, InvoiceDetail inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RecordPaymentSheet(invoice: inv, ref: ref, invoiceId: invoiceId),
    );
  }

  Future<void> _cancelInvoice(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: const Text(
            'Are you sure you want to cancel this invoice? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/api/invoices/$id', data: {'status': 'CANCELLED'});
      ref.invalidate(invoiceDetailProvider(id));
    } on DioException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['message'] ?? 'Failed to cancel invoice'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _InvoiceDetailBody extends StatelessWidget {
  const _InvoiceDetailBody({
    required this.invoice,
    required this.onEdit,
    required this.onRecordPayment,
    required this.onCancel,
  });

  final InvoiceDetail invoice;
  final VoidCallback onEdit;
  final VoidCallback onRecordPayment;
  final VoidCallback onCancel;

  static Color _statusColor(String s) => switch (s) {
        'PAID' => AppColors.success,
        'PARTIAL' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        'SENT' => AppColors.info,
        'CANCELLED' => AppColors.grey500,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(invoice.status);
    final isDraft = invoice.status == 'DRAFT';
    final isCancelled = invoice.status == 'CANCELLED';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Header card
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invoice.invoiceNumber,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(Formatters.date(invoice.date),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      Formatters.invoiceStatus(invoice.status),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (invoice.dueDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Due: ${Formatters.date(invoice.dueDate)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Party details
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bill To',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(invoice.partyName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (invoice.partyGstin != null) ...[
                const SizedBox(height: 4),
                Text('GSTIN: ${invoice.partyGstin}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
              if (invoice.partyAddress != null) ...[
                const SizedBox(height: 4),
                Text(invoice.partyAddress!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
              if (invoice.partyMobile != null) ...[
                const SizedBox(height: 4),
                Text('📞 ${invoice.partyMobile}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Items Table
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Items',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...invoice.items.asMap().entries.map((e) {
                final i = e.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key < invoice.items.length - 1 ? 12 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.key > 0) const Divider(height: 1),
                      if (e.key > 0) const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${Formatters.quantity(i.quantity, unit: i.unit)} × ${Formatters.currency(i.rate)}'
                                  '${i.discountPercent > 0 ? ' − ${i.discountPercent}%' : ''}'
                                  ' | GST ${i.taxRate}%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                if (i.hsn != null)
                                  Text('HSN: ${i.hsn}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Text(Formatters.currency(i.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // GST Breakdown & Totals
        _Card(
          child: Column(
            children: [
              _TotalRow('Subtotal', invoice.subtotal),
              if (invoice.totalDiscount > 0)
                _TotalRow('Discount', -invoice.totalDiscount,
                    color: AppColors.success),
              _TotalRow('Taxable Amount', invoice.taxableAmount),
              if (invoice.igst > 0)
                _TotalRow('IGST', invoice.igst)
              else ...[
                if (invoice.cgst > 0) _TotalRow('CGST', invoice.cgst),
                if (invoice.sgst > 0) _TotalRow('SGST', invoice.sgst),
              ],
              const Divider(height: 20),
              _TotalRow('Grand Total', invoice.grandTotal,
                  bold: true, large: true),
              if (invoice.balanceDue > 0) ...[
                const SizedBox(height: 6),
                _TotalRow('Balance Due', invoice.balanceDue,
                    bold: true, color: AppColors.error),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Payment History
        if (invoice.payments.isNotEmpty) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment History',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ...invoice.payments.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payments_outlined,
                                color: AppColors.success, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Formatters.paymentMode(p.mode),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13)),
                                Text(Formatters.date(p.date),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Text(Formatters.currency(p.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                  fontSize: 13)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Notes & Terms
        if ((invoice.notes != null && invoice.notes!.isNotEmpty) ||
            (invoice.terms != null && invoice.terms!.isNotEmpty))
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                  const Text('Notes',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(invoice.notes!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                ],
                if (invoice.terms != null && invoice.terms!.isNotEmpty) ...[
                  const Text('Terms & Conditions',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(invoice.terms!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                ],
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Action Buttons
        if (!isCancelled)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (invoice.balanceDue > 0)
                ElevatedButton.icon(
                  onPressed: onRecordPayment,
                  icon: const Icon(Icons.payment),
                  label: const Text('Record Payment',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (invoice.balanceDue > 0) const SizedBox(height: 10),
              if (isDraft)
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Invoice',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (isDraft) const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Invoice',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amount,
      {this.bold = false, this.large = false, this.color});

  final String label;
  final double amount;
  final bool bold;
  final bool large;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: large ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: large ? AppColors.textPrimary : AppColors.textSecondary,
              )),
          Text(Formatters.currency(amount.abs()),
              style: TextStyle(
                fontSize: large ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Record Payment Sheet
// ---------------------------------------------------------------------------

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({
    required this.invoice,
    required this.ref,
    required this.invoiceId,
  });

  final InvoiceDetail invoice;
  final WidgetRef ref;
  final String invoiceId;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _mode = 'CASH';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.invoice.balanceDue.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter valid amount'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/payments', data: {
        'invoiceId': widget.invoice.id,
        'amount': amount,
        'mode': _mode,
        'date': Formatters.isoDate(DateTime.now()),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            e.response?.data?['message'] ?? 'Failed to record payment'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Record Payment',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Balance Due: ${Formatters.currency(widget.invoice.balanceDue)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount Received *',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFF9FAFB),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _mode,
            decoration: const InputDecoration(
              labelText: 'Payment Mode',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFF9FAFB),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(
                  value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'CASH'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _record,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Record Payment',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
