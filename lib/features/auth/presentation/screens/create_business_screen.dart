import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _createBusinessLoadingProvider = StateProvider<bool>((ref) => false);

const _businessTypes = ['Retail', 'Wholesale', 'Service', 'Manufacturing'];
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

class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  ConsumerState<CreateBusinessScreen> createState() =>
      _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _businessType;
  String? _selectedState;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _legalNameCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_createBusinessLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.post('/api/businesses', data: {
        'name': _nameCtrl.text.trim(),
        'legalName': _legalNameCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim().toUpperCase(),
        'pan': _panCtrl.text.trim().toUpperCase(),
        'type': _businessType?.toUpperCase(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _selectedState,
        'pincode': _pincodeCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });
      final data = resp.data as Map<String, dynamic>;
      final businessId = data['id']?.toString() ?? data['business']?['id']?.toString();
      if (businessId != null) {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'business_id', value: businessId);
      }
      if (!mounted) return;
      context.go('/home');
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.response?.data?['message'] ?? 'Failed to create business'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) ref.read(_createBusinessLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_createBusinessLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Business'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('Business Information'),
            const SizedBox(height: 12),
            _buildField(
              controller: _nameCtrl,
              label: 'Business Name *',
              hint: 'e.g. Sharma Enterprises',
              icon: Icons.store,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Business name is required' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _legalNameCtrl,
              label: 'Legal Name',
              hint: 'Legal/registered name',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _gstinCtrl,
              label: 'GSTIN',
              hint: '15-character GSTIN',
              icon: Icons.numbers,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(15),
                _UpperCaseTextFormatter(),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 15) return 'GSTIN must be 15 characters';
                final reg = RegExp(
                    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                if (!reg.hasMatch(v)) return 'Invalid GSTIN format';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _panCtrl,
              label: 'PAN',
              hint: '10-character PAN',
              icon: Icons.credit_card_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
                _UpperCaseTextFormatter(),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v)) {
                  return 'Invalid PAN format';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildDropdown<String>(
              value: _businessType,
              items: _businessTypes,
              label: 'Business Type',
              icon: Icons.category_outlined,
              itemLabel: (e) => e,
              onChanged: (v) => setState(() => _businessType = v),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Address'),
            const SizedBox(height: 12),
            _buildField(
              controller: _addressCtrl,
              label: 'Address',
              hint: 'Street, Building, Area',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _cityCtrl,
                    label: 'City',
                    hint: 'City',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _pincodeCtrl,
                    label: 'Pincode',
                    hint: '6-digit',
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
            _buildDropdown<String>(
              value: _selectedState,
              items: _indianStates,
              label: 'State',
              icon: Icons.map_outlined,
              itemLabel: (e) => e,
              onChanged: (v) => setState(() => _selectedState = v),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Contact'),
            const SizedBox(height: 12),
            _buildField(
              controller: _phoneCtrl,
              label: 'Phone',
              hint: '10-digit mobile number',
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
            _buildField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'business@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!v.contains('@')) return 'Enter valid email';
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
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
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Create Business',
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

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required IconData icon,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text(itemLabel(e)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
