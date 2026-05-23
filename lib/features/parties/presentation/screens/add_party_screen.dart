import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _addPartyLoadingProvider = StateProvider<bool>((ref) => false);

const _indianStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Delhi',
  'Jammu & Kashmir',
  'Ladakh',
];

class AddPartyScreen extends ConsumerStatefulWidget {
  const AddPartyScreen({super.key});

  @override
  ConsumerState<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends ConsumerState<AddPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();

  String _partyType = 'CUSTOMER';
  String? _selectedState;
  String _balanceType = 'DEBIT';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _creditLimitCtrl.dispose();
    _creditDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_addPartyLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/parties', data: {
        'name': _nameCtrl.text.trim(),
        'type': _partyType,
        'mobile': _mobileCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim().toUpperCase(),
        'pan': _panCtrl.text.trim().toUpperCase(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _selectedState,
        'pincode': _pincodeCtrl.text.trim(),
        'openingBalance':
            double.tryParse(_openingBalanceCtrl.text) ?? 0,
        'balanceType': _balanceType,
        if (_creditLimitCtrl.text.isNotEmpty)
          'creditLimit': double.tryParse(_creditLimitCtrl.text),
        if (_creditDaysCtrl.text.isNotEmpty)
          'creditDays': int.tryParse(_creditDaysCtrl.text),
      });
      if (!mounted) return;
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(e.response?.data?['message'] ?? 'Failed to save party'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } finally {
      if (mounted) ref.read(_addPartyLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_addPartyLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            const Text('Add Party', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info
            _sectionHeader('Basic Information'),
            const SizedBox(height: 12),
            _field(
              controller: _nameCtrl,
              label: 'Name *',
              icon: Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _partyType,
              decoration: _inputDecoration('Party Type', Icons.category_outlined),
              items: const [
                DropdownMenuItem(
                    value: 'CUSTOMER', child: Text('Customer')),
                DropdownMenuItem(
                    value: 'SUPPLIER', child: Text('Supplier')),
                DropdownMenuItem(value: 'BOTH', child: Text('Both')),
              ],
              onChanged: (v) => setState(() => _partyType = v ?? 'CUSTOMER'),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _mobileCtrl,
              label: 'Mobile',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 10) return 'Enter valid 10-digit number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              controller: _emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!v.contains('@')) return 'Enter valid email';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // GST Info
            _sectionHeader('GST Information'),
            const SizedBox(height: 12),
            _field(
              controller: _gstinCtrl,
              label: 'GSTIN',
              icon: Icons.numbers,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(15),
                _UpperCaseFormatter(),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 15) return 'GSTIN must be 15 characters';
                if (!RegExp(
                        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
                    .hasMatch(v)) {
                  return 'Invalid GSTIN format';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              controller: _panCtrl,
              label: 'PAN',
              icon: Icons.credit_card_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
                _UpperCaseFormatter(),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v)) {
                  return 'Invalid PAN format';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Address
            _sectionHeader('Billing Address'),
            const SizedBox(height: 12),
            _field(
              controller: _addressCtrl,
              label: 'Address',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _cityCtrl,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _pincodeCtrl,
                    label: 'Pincode',
                    icon: Icons.pin_drop_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (v.length != 6) return 'Invalid pincode';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration:
                  _inputDecoration('State', Icons.map_outlined),
              items: _indianStates
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedState = v),
            ),
            const SizedBox(height: 20),

            // Financial
            _sectionHeader('Financial Details'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _openingBalanceCtrl,
                    label: 'Opening Balance',
                    icon: Icons.account_balance_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _balanceType,
                    decoration: _inputDecoration(
                        'Balance Type', Icons.compare_arrows_rounded),
                    items: const [
                      DropdownMenuItem(
                          value: 'DEBIT', child: Text('Debit (To Pay)')),
                      DropdownMenuItem(
                          value: 'CREDIT', child: Text('Credit (To Collect)')),
                    ],
                    onChanged: (v) =>
                        setState(() => _balanceType = v ?? 'DEBIT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _creditLimitCtrl,
                    label: 'Credit Limit (₹)',
                    icon: Icons.credit_score_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _creditDaysCtrl,
                    label: 'Credit Days',
                    icon: Icons.event_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    : const Text('Save Party',
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

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      );

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
