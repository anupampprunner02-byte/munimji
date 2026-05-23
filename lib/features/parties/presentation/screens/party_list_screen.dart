import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class PartySummary {
  final String id;
  final String name;
  final String type;
  final String? mobile;
  final String? gstin;
  final double outstandingBalance;
  final String balanceType; // 'DEBIT' | 'CREDIT'

  const PartySummary({
    required this.id,
    required this.name,
    required this.type,
    this.mobile,
    this.gstin,
    required this.outstandingBalance,
    required this.balanceType,
  });

  factory PartySummary.fromJson(Map<String, dynamic> j) => PartySummary(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? 'CUSTOMER',
        mobile: j['mobile']?.toString(),
        gstin: j['gstin']?.toString(),
        outstandingBalance:
            (j['outstandingBalance'] as num?)?.toDouble() ?? 0,
        balanceType: j['balanceType']?.toString() ?? 'DEBIT',
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _partyTabProvider = StateProvider<int>((ref) => 0);
final _partySearchQueryProvider = StateProvider<String>((ref) => '');

final partyListProvider =
    FutureProvider.family<List<PartySummary>, String>((ref, type) async {
  final api = ref.read(apiClientProvider);
  final search = ref.read(_partySearchQueryProvider);
  final params = <String, dynamic>{
    'limit': 100,
    'sortBy': 'name',
    if (type != 'ALL') 'type': type,
    if (search.isNotEmpty) 'search': search,
  };
  final data = await api.get('/api/parties', queryParameters: params);
  final list = data['data'] as List<dynamic>? ?? [];
  return list
      .map((e) => PartySummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PartyListScreen extends ConsumerStatefulWidget {
  const PartyListScreen({super.key});

  @override
  ConsumerState<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends ConsumerState<PartyListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  static const _tabs = [
    ('CUSTOMER', 'Customers'),
    ('SUPPLIER', 'Suppliers'),
    ('ALL', 'All'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      ref.read(_partyTabProvider.notifier).state = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _currentType => _tabs[_tabController.index].$1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            const Text('Parties', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: _tabs
              .map((t) => Tab(text: t.$2))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search by name, mobile, GSTIN…',
              leading: const Icon(Icons.search, color: AppColors.textSecondary),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(_partySearchQueryProvider.notifier).state = '';
                      ref.invalidate(partyListProvider(_currentType));
                    },
                  ),
              ],
              backgroundColor: WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.all(0),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
              onChanged: (v) {
                ref.read(_partySearchQueryProvider.notifier).state = v;
                ref.invalidate(partyListProvider(_currentType));
              },
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((t) => _PartyTabView(type: t.$1))
                  .toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/parties/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }
}

class _PartyTabView extends ConsumerWidget {
  const _PartyTabView({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partiesAsync = ref.watch(partyListProvider(type));

    return partiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('Failed to load parties',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
                onPressed: () => ref.invalidate(partyListProvider(type)),
                child: const Text('Retry')),
          ],
        ),
      ),
      data: (parties) {
        if (parties.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline,
                    size: 72, color: AppColors.grey300),
                const SizedBox(height: 16),
                const Text('No parties found',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text('Add a party to get started',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push('/parties/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Party'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(partyListProvider(type)),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: parties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => PartyCard(party: parties[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Party Card
// ---------------------------------------------------------------------------

class PartyCard extends StatelessWidget {
  const PartyCard({super.key, required this.party});

  final PartySummary party;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF00695C),
      Color(0xFF6A1B9A),
      Color(0xFFE65100),
      Color(0xFF1B5E20),
      Color(0xFF880E4F),
    ];
    final idx = name.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = party.balanceType == 'CREDIT';
    final balanceColor =
        isCredit ? AppColors.success : AppColors.error;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/parties/${party.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: _avatarColor(party.name),
                child: Text(
                  _initials(party.name),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(party.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    if (party.mobile != null) ...[
                      Text(party.mobile!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    if (party.gstin != null && party.gstin!.isNotEmpty)
                      Text('GST: ${party.gstin}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Balance
              if (party.outstandingBalance > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currencyCompact(party.outstandingBalance),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: balanceColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isCredit ? 'To Collect' : 'To Pay',
                      style: TextStyle(
                          fontSize: 10,
                          color: balanceColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
