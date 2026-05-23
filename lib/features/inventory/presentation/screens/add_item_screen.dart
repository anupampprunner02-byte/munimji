import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _addItemLoadingProvider = StateProvider<bool>((ref) => false);

const _units = [
  'PCS',
  'KG',
  'G',
  'L',
  'ML',
  'MTR',
  'CM',
  'BOX',
  'SET',
  'NOS',
  'PKT',
  'BAG',
  'DOZEN',
  'PAIR',
  'SQ_MTR',
  'CU_MTR',
  'TON',
];

const _taxRates = ['0', '0.1', '0.25', '1', '1.5', '3', '5', '6', '12', '18', '28'];

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _openingStockCtrl = TextEditingController();
  final _lowStockAlertCtrl = TextEditingController();
  final _reorderPointCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _unit = 'PCS';
  String _taxRate = '18';
  bool _isTaxInclusive = false;
  bool _isService = false;
  bool _trackBatch = false;
  bool _trackSerial = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _hsnCtrl.dispose();
    _categoryCtrl.dispose();
    _salePriceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _mrpCtrl.dispose();
    _openingStockCtrl.dispose();
    _lowStockAlertCtrl.dispose();
    _reorderPointCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_addItemLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/items', data: {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim(),
        'hsnCode': _hsnCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'unit': _unit,
        'salePrice': double.tryParse(_salePriceCtrl.text) ?? 0,
        if (_purchasePriceCtrl.text.isNotEmpty)
          'purchasePrice': double.tryParse(_purchasePriceCtrl.text),
        if (_mrpCtrl.text.isNotEmpty)
          'mrp': double.tryParse(_mrpCtrl.text),
        'taxRate': double.tryParse(_taxRate) ?? 0,
        'isTaxInclusive': _isTaxInclusive,
        'isService': _isService,
        if (!_isService) ...{
          'openingStock': double.tryParse(_openingStockCtrl.text) ?? 0,
          if (_lowStockAlertCtrl.text.isNotEmpty)
            'lowStockAlert': double.tryParse(_lowStockAlertCtrl.text),
          if (_reorderPointCtrl.text.isNotEmpty)
            'reorderPoint': double.tryParse(_reorderPointCtrl.text),
          'trackBatch': _trackBatch,
          'trackSerial': _trackSerial,
        },
        if (_descriptionCtrl.text.isNotEmpty)
          'description': _descriptionCtrl.text.trim(),
      });
      if (!mounted) return;
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['message'] ?? 'Failed to save item'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } finally {
      if (mounted) ref.read(_addItemLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_addItemLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Item',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Service toggle at top
            _Card(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Is Service',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Services don\'t track stock',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isService,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isService = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Basic Info
            _CardSection(
              title: 'Basic Information',
              icon: Icons.info_outline,
              children: [
                _field(
                  controller: _nameCtrl,
                  label: 'Item Name *',
                  icon: Icons.inventory_2_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Item name is required'
                          : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _codeCtrl,
                        label: 'Item Code',
                        icon: Icons.qr_code_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        controller: _hsnCtrl,
                        label: 'HSN / SAC Code',
                        icon: Icons.tag_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _categoryCtrl,
                  label: 'Category',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: _inputDec('Unit', Icons.straighten_outlined),
                  items: _units
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? 'PCS'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pricing
            _CardSection(
              title: 'Pricing',
              icon: Icons.attach_money_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _salePriceCtrl,
                        label: 'Sale Price *',
                        icon: Icons.sell_outlined,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Sale price required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        controller: _purchasePriceCtrl,
                        label: 'Purchase Price',
                        icon: Icons.shopping_cart_outlined,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _mrpCtrl,
                  label: 'MRP',
                  icon: Icons.local_offer_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _taxRate,
                        decoration: _inputDec('GST Rate (%)',
                            Icons.percent_rounded),
                        items: _taxRates
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text('$r%')))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _taxRate = v ?? '18'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SwitchTile(
                        label: 'Tax Inclusive',
                        value: _isTaxInclusive,
                        onChanged: (v) =>
                            setState(() => _isTaxInclusive = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stock (only for products)
            if (!_isService) ...[
              _CardSection(
                title: 'Stock Management',
                icon: Icons.warehouse_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _openingStockCtrl,
                          label: 'Opening Stock',
                          icon: Icons.inventory_outlined,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _lowStockAlertCtrl,
                          label: 'Low Stock Alert',
                          icon: Icons.warning_amber_outlined,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _reorderPointCtrl,
                    label: 'Reorder Point',
                    icon: Icons.refresh_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                  ),
                  const SizedBox(height: 12),
                  _SwitchTile(
                    label: 'Track Batch Number',
                    subtitle: 'Enable batch tracking for this item',
                    value: _trackBatch,
                    onChanged: (v) => setState(() => _trackBatch = v),
                  ),
                  const Divider(height: 16),
                  _SwitchTile(
                    label: 'Track Serial Number',
                    subtitle: 'Enable serial number tracking',
                    value: _trackSerial,
                    onChanged: (v) => setState(() => _trackSerial = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Description
            _CardSection(
              title: 'Additional Details',
              icon: Icons.notes_outlined,
              children: [
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Product description…',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save Item',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
        decoration: _inputDec(label, icon),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
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

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
