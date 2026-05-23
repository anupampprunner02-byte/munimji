import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _Party {
  final String id;
  final String name;
  final String? gstin;

  const _Party({required this.id, required this.name, this.gstin});

  factory _Party.fromJson(Map<String, dynamic> j) => _Party(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        gstin: j['gstin']?.toString(),
      );
}

class _Item {
  final String id;
  final String name;
  final String? code;
  final double salePrice;
  final double taxRate;
  final String unit;

  const _Item({
    required this.id,
    required this.name,
    this.code,
    required this.salePrice,
    required this.taxRate,
    required this.unit,
  });

  factory _Item.fromJson(Map<String, dynamic> j) => _Item(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        code: j['code']?.toString(),
        salePrice: (j['salePrice'] as num?)?.toDouble() ?? 0,
        taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0,
        unit: j['unit']?.toString() ?? 'PCS',
      );
}

class _InvoiceItem {
  final String itemId;
  final String itemName;
  final String unit;
  double quantity;
  double rate;
  double discountPercent;
  double taxRate;

  _InvoiceItem({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.rate,
    this.discountPercent = 0,
    required this.taxRate,
  });

  double get baseAmount => quantity * rate;
  double get discountAmount => baseAmount * discountPercent / 100;
  double get taxableAmount => baseAmount - discountAmount;
  double get taxAmount => taxableAmount * taxRate / 100;
  double get total => taxableAmount + taxAmount;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _partySearchProvider =
    FutureProvider.family<List<_Party>, String>((ref, q) async {
  if (q.isEmpty) return [];
  final api = ref.read(apiClientProvider);
  final data =
      await api.get('/api/parties', queryParameters: {'search': q, 'limit': 10});
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => _Party.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _itemSearchProvider =
    FutureProvider.family<List<_Item>, String>((ref, q) async {
  if (q.isEmpty) return [];
  final api = ref.read(apiClientProvider);
  final data = await api.get('/api/items', queryParameters: {
    'search': q,
    'limit': 10,
    'type': 'PRODUCT,SERVICE',
  });
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => _Item.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _paymentAmountCtrl = TextEditingController();

  _Party? _selectedParty;
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String _invoiceType = 'SALE';
  String _paymentMode = 'CASH';
  bool _hasPayment = false;
  bool _isLoading = false;

  final List<_InvoiceItem> _items = [];

  @override
  void dispose() {
    _notesCtrl.dispose();
    _termsCtrl.dispose();
    _paymentAmountCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + i.baseAmount);

  double get _totalDiscount =>
      _items.fold(0, (sum, i) => sum + i.discountAmount);

  double get _taxableAmount =>
      _items.fold(0, (sum, i) => sum + i.taxableAmount);

  double get _totalTax => _items.fold(0, (sum, i) => sum + i.taxAmount);

  double get _grandTotal => _taxableAmount + _totalTax;

  // Tax breakdown (CGST/SGST split when intra-state, else IGST)
  Map<double, double> get _taxBreakdown {
    final breakdown = <double, double>{};
    for (final item in _items) {
      breakdown[item.taxRate] =
          (breakdown[item.taxRate] ?? 0) + item.taxAmount;
    }
    return breakdown;
  }

  String _amountInWords(double amount) {
    final n = amount.toInt();
    if (n == 0) return 'Zero Rupees Only';
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];
    String convert(int num) {
      if (num < 20) return ones[num];
      if (num < 100) {
        return '${tens[num ~/ 10]}${num % 10 != 0 ? ' ${ones[num % 10]}' : ''}';
      }
      if (num < 1000) {
        return '${ones[num ~/ 100]} Hundred${num % 100 != 0 ? ' ${convert(num % 100)}' : ''}';
      }
      return num.toString();
    }

    String result = '';
    if (n >= 10000000) result += '${convert(n ~/ 10000000)} Crore ';
    if (n % 10000000 >= 100000) result += '${convert((n % 10000000) ~/ 100000)} Lakh ';
    if (n % 100000 >= 1000) result += '${convert((n % 100000) ~/ 1000)} Thousand ';
    if (n % 1000 > 0) result += convert(n % 1000);
    return '${result.trim()} Rupees Only';
  }

  Future<void> _save({bool asDraft = false}) async {
    if (_selectedParty == null) {
      _showError('Please select a party');
      return;
    }
    if (_items.isEmpty) {
      _showError('Please add at least one item');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'partyId': _selectedParty!.id,
        'date': Formatters.isoDate(_invoiceDate),
        'dueDate': _dueDate != null ? Formatters.isoDate(_dueDate!) : null,
        'type': _invoiceType,
        'status': asDraft ? 'DRAFT' : 'SENT',
        'notes': _notesCtrl.text.trim(),
        'terms': _termsCtrl.text.trim(),
        'items': _items
            .map((i) => {
                  'itemId': i.itemId,
                  'quantity': i.quantity,
                  'rate': i.rate,
                  'discountPercent': i.discountPercent,
                  'taxRate': i.taxRate,
                })
            .toList(),
        if (_hasPayment && _paymentAmountCtrl.text.isNotEmpty)
          'payment': {
            'mode': _paymentMode,
            'amount': double.tryParse(_paymentAmountCtrl.text) ?? 0,
          },
      };
      final data = await api.post('/api/invoices', data: payload);
      final id = data['id']?.toString() ?? data['invoice']?['id']?.toString();
      if (!mounted) return;
      context.pushReplacement('/invoices/$id');
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(e.response?.data?['message'] ?? 'Failed to save invoice');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Invoice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _save(asDraft: true),
            child: const Text('Draft',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Section 1: Party & Date
            _SectionCard(
              title: 'Party & Date',
              icon: Icons.person_outline,
              children: [
                _PartySelector(
                  selected: _selectedParty,
                  onSelected: (p) => setState(() => _selectedParty = p),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Invoice Date',
                        date: _invoiceDate,
                        onChanged: (d) => setState(() => _invoiceDate = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Due Date',
                        date: _dueDate,
                        optional: true,
                        onChanged: (d) => setState(() => _dueDate = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _invoiceType,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Type',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SALE', child: Text('Sale')),
                    DropdownMenuItem(
                        value: 'ESTIMATE', child: Text('Estimate')),
                    DropdownMenuItem(
                        value: 'PROFORMA', child: Text('Proforma')),
                    DropdownMenuItem(
                        value: 'DELIVERY_CHALLAN',
                        child: Text('Delivery Challan')),
                  ],
                  onChanged: (v) =>
                      setState(() => _invoiceType = v ?? 'SALE'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Section 2: Items
            _SectionCard(
              title: 'Items',
              icon: Icons.inventory_2_outlined,
              trailing: TextButton.icon(
                onPressed: _showAddItemSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
              ),
              children: [
                if (_items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No items added yet',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _ItemRow(
                      item: _items[i],
                      onDelete: () =>
                          setState(() => _items.removeAt(i)),
                      onEdit: () => _showEditItemSheet(i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Section 3: Summary
            _SectionCard(
              title: 'Summary',
              icon: Icons.calculate_outlined,
              children: [
                _SummaryRow('Subtotal', _subtotal),
                _SummaryRow('Discount', -_totalDiscount,
                    color: AppColors.success),
                _SummaryRow('Taxable Amount', _taxableAmount,
                    bold: true),
                ..._taxBreakdown.entries.map((e) => Column(
                      children: [
                        _SummaryRow(
                            'CGST @ ${e.key / 2}%', e.value / 2),
                        _SummaryRow(
                            'SGST @ ${e.key / 2}%', e.value / 2),
                      ],
                    )),
                const Divider(height: 16),
                _SummaryRow('Grand Total', _grandTotal,
                    bold: true, large: true),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _amountInWords(_grandTotal),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Section 4: Payment
            _SectionCard(
              title: 'Payment',
              icon: Icons.payments_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Record Payment'),
                  value: _hasPayment,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _hasPayment = v),
                ),
                if (_hasPayment) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          decoration: const InputDecoration(
                            labelText: 'Payment Mode',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'CASH', child: Text('Cash')),
                            DropdownMenuItem(
                                value: 'UPI', child: Text('UPI')),
                            DropdownMenuItem(
                                value: 'BANK_TRANSFER',
                                child: Text('Bank Transfer')),
                            DropdownMenuItem(
                                value: 'CHEQUE',
                                child: Text('Cheque')),
                            DropdownMenuItem(
                                value: 'CARD', child: Text('Card')),
                          ],
                          onChanged: (v) =>
                              setState(() => _paymentMode = v ?? 'CASH'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _paymentAmountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount Received',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Section 5: Notes
            _SectionCard(
              title: 'Notes & Terms',
              icon: Icons.notes_outlined,
              children: [
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any notes for the customer…',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Terms & Conditions',
                    hintText: 'Payment terms, delivery terms…',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _save(asDraft: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save as Draft',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _save(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                        : const Text('Save & Share',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        onAdd: (item) {
          setState(() => _items.add(item));
        },
      ),
    );
  }

  void _showEditItemSheet(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        existingItem: _items[index],
        onAdd: (item) {
          setState(() => _items[index] = item);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting Widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children),
          ),
        ],
      ),
    );
  }
}

class _PartySelector extends ConsumerStatefulWidget {
  const _PartySelector({required this.selected, required this.onSelected});

  final _Party? selected;
  final void Function(_Party) onSelected;

  @override
  ConsumerState<_PartySelector> createState() => _PartySelectorState();
}

class _PartySelectorState extends ConsumerState<_PartySelector> {
  final _ctrl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _ctrl.text = widget.selected!.name;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_partySearchProvider(_ctrl.text));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'Party / Customer *',
            hintText: 'Search party name…',
            prefixIcon: const Icon(Icons.person_search_outlined),
            suffixIcon: widget.selected != null
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : null,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (_) => widget.selected == null ? 'Select a party' : null,
          onChanged: (v) {
            setState(() => _searching = v.isNotEmpty);
          },
        ),
        if (_searching)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.grey300),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: results.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Search failed')),
              data: (parties) => ListView.builder(
                shrinkWrap: true,
                itemCount: parties.length,
                itemBuilder: (ctx, i) => ListTile(
                  dense: true,
                  title: Text(parties[i].name),
                  subtitle: parties[i].gstin != null
                      ? Text(parties[i].gstin!)
                      : null,
                  onTap: () {
                    widget.onSelected(parties[i]);
                    _ctrl.text = parties[i].name;
                    setState(() => _searching = false);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
    this.optional = false,
  });

  final String label;
  final DateTime? date;
  final bool optional;
  final void Function(DateTime) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            hintText: optional ? 'Optional' : null,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          controller: TextEditingController(
            text: date != null
                ? DateFormat('dd/MM/yyyy').format(date!)
                : '',
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(
      {required this.item, required this.onDelete, required this.onEdit});

  final _InvoiceItem item;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${Formatters.quantity(item.quantity, unit: item.unit)} × ${Formatters.currency(item.rate)}'
                  '${item.discountPercent > 0 ? ' | Disc: ${item.discountPercent}%' : ''}'
                  ' | Tax: ${item.taxRate}%',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(Formatters.currency(item.total),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            child: const Icon(Icons.more_vert,
                size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
    this.label,
    this.amount, {
    this.bold = false,
    this.large = false,
    this.color,
  });

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
// Add Item Bottom Sheet
// ---------------------------------------------------------------------------

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet({required this.onAdd, this.existingItem});

  final void Function(_InvoiceItem) onAdd;
  final _InvoiceItem? existingItem;

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _itemSearchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _discCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '18');

  _Item? _selectedItem;
  bool _searchingItem = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingItem;
    if (ex != null) {
      _itemSearchCtrl.text = ex.itemName;
      _qtyCtrl.text = ex.quantity.toString();
      _rateCtrl.text = ex.rate.toString();
      _discCtrl.text = ex.discountPercent.toString();
      _taxCtrl.text = ex.taxRate.toString();
      _selectedItem = _Item(
          id: ex.itemId,
          name: ex.itemName,
          salePrice: ex.rate,
          taxRate: ex.taxRate,
          unit: ex.unit);
    }
  }

  @override
  void dispose() {
    _itemSearchCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _discCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_selectedItem == null && _itemSearchCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item')),
      );
      return;
    }
    final item = _InvoiceItem(
      itemId: _selectedItem?.id ?? '',
      itemName: _selectedItem?.name ?? _itemSearchCtrl.text,
      unit: _selectedItem?.unit ?? 'PCS',
      quantity: double.tryParse(_qtyCtrl.text) ?? 1,
      rate: double.tryParse(_rateCtrl.text) ?? 0,
      discountPercent: double.tryParse(_discCtrl.text) ?? 0,
      taxRate: double.tryParse(_taxCtrl.text) ?? 0,
    );
    widget.onAdd(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(_itemSearchProvider(_itemSearchCtrl.text));

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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingItem != null ? 'Edit Item' : 'Add Item',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemSearchCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                hintText: 'Search or type item name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF9FAFB),
              ),
              onChanged: (v) => setState(() => _searchingItem = v.isNotEmpty),
            ),
            if (_searchingItem)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.grey300),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8)),
                ),
                child: searchResults.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator())),
                  error: (_, __) =>
                      const Padding(padding: EdgeInsets.all(12), child: Text('Error')),
                  data: (items) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => ListTile(
                      dense: true,
                      title: Text(items[i].name),
                      subtitle: Text(
                          '${Formatters.currency(items[i].salePrice)} | GST ${items[i].taxRate}%'),
                      onTap: () {
                        setState(() {
                          _selectedItem = items[i];
                          _itemSearchCtrl.text = items[i].name;
                          _rateCtrl.text = items[i].salePrice.toString();
                          _taxCtrl.text = items[i].taxRate.toString();
                          _searchingItem = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rate (₹)',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _discCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Discount %',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _taxCtrl.text.isNotEmpty ? _taxCtrl.text : '18',
                    decoration: const InputDecoration(
                      labelText: 'GST Rate',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF9FAFB),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: '0', child: Text('0%')),
                      DropdownMenuItem(value: '3', child: Text('3%')),
                      DropdownMenuItem(value: '5', child: Text('5%')),
                      DropdownMenuItem(value: '12', child: Text('12%')),
                      DropdownMenuItem(value: '18', child: Text('18%')),
                      DropdownMenuItem(value: '28', child: Text('28%')),
                    ],
                    onChanged: (v) =>
                        setState(() => _taxCtrl.text = v ?? '18'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                widget.existingItem != null ? 'Update Item' : 'Add Item',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
