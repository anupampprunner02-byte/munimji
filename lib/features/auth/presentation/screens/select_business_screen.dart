import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

class _BusinessMembership {
  final String id;
  final String name;
  final String? gstin;
  final String? logoUrl;
  final String role;

  const _BusinessMembership({
    required this.id,
    required this.name,
    this.gstin,
    this.logoUrl,
    required this.role,
  });

  factory _BusinessMembership.fromJson(Map<String, dynamic> json) {
    final biz = json['business'] as Map<String, dynamic>? ?? json;
    return _BusinessMembership(
      id: biz['id']?.toString() ?? '',
      name: biz['name']?.toString() ?? '',
      gstin: biz['gstin']?.toString(),
      logoUrl: biz['logoUrl']?.toString(),
      role: json['role']?.toString() ?? 'OWNER',
    );
  }
}

final _businessListProvider =
    FutureProvider<List<_BusinessMembership>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/api/auth/me');
  final memberships = data['businesses'] as List<dynamic>? ?? [];
  return memberships
      .map((e) => _BusinessMembership.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SelectBusinessScreen extends ConsumerWidget {
  const SelectBusinessScreen({super.key});

  Future<void> _selectBusiness(
      BuildContext context, String businessId) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'business_id', value: businessId);
    if (!context.mounted) return;
    context.go('/home');
  }

  Color _roleColor(String role) {
    return switch (role.toUpperCase()) {
      'OWNER' => AppColors.primary,
      'ADMIN' => AppColors.accent,
      'ACCOUNTANT' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(_businessListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business_center_rounded,
                      size: 48, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Select Business',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Choose the business you want to manage',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: businessAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load businesses',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref.invalidate(_businessListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (businesses) {
                  if (businesses.isEmpty) {
                    return _EmptyBusinessView(
                        onCreateTap: () => context.push('/create-business'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: businesses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final biz = businesses[index];
                      return _BusinessCard(
                        business: biz,
                        roleColor: _roleColor(biz.role),
                        onTap: () =>
                            _selectBusiness(context, biz.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-business'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create New Business',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.roleColor,
    required this.onTap,
  });

  final _BusinessMembership business;
  final Color roleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store_rounded,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (business.gstin != null &&
                        business.gstin!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'GSTIN: ${business.gstin}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        business.role,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBusinessView extends StatelessWidget {
  const _EmptyBusinessView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined,
                size: 80, color: AppColors.grey300),
            const SizedBox(height: 20),
            const Text(
              'No Business Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first business to get started with GST accounting',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create Business'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
