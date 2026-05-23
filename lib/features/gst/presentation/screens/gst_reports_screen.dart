import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';

final gstrProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Map<String, dynamic>>(
  (ref, params) async {
    final storage = const FlutterSecureStorage();
    final businessId = await storage.read(key: 'business_id');
    if (businessId == null) return {};
    return await ApiClient().get('/v1/$businessId/reports/gstr',
        params: {'month': params['month'].toString(), 'year': params['year'].toString()});
  },
);

class GstReportsScreen extends ConsumerStatefulWidget {
  const GstReportsScreen({super.key});

  @override
  ConsumerState<GstReportsScreen> createState() => _GstReportsScreenState();
}

class _GstReportsScreenState extends ConsumerState<GstReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gstrAsync = ref.watch(gstrProvider({'month': _selectedMonth, 'year': _selectedYear}));

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'GSTR-1'), Tab(text: 'GSTR-3B'), Tab(text: 'HSN Summary')],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: Column(children: [
        // Period selector
        Container(
          color: AppColors.grey50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Text('Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
                onChanged: (v) => setState(() => _selectedMonth = v!),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: List.generate(5, (i) => DropdownMenuItem(
                  value: DateTime.now().year - i,
                  child: Text('${DateTime.now().year - i}'),
                )),
                onChanged: (v) => setState(() => _selectedYear = v!),
              ),
            ),
          ]),
        ),
        Expanded(
          child: gstrAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => TabBarView(
              controller: _tabController,
              children: [
                _Gstr1Tab(data: data['data'] ?? {}),
                _Gstr3bTab(data: data['data'] ?? {}),
                _HsnSummaryTab(data: data['data'] ?? {}),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Gstr1Tab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Gstr1Tab({required this.data});

  @override
  Widget build(BuildContext context) {
    final b2b = (data['b2b'] as List?) ?? [];
    final b2cs = (data['b2cs'] as List?) ?? [];

    return ListView(padding: const EdgeInsets.all(16), children: [
      _SectionCard(
        title: 'B2B Invoices (With GSTIN)',
        subtitle: '${b2b.length} parties',
        icon: Icons.business,
        color: AppColors.primary,
        child: b2b.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Text('No B2B invoices this period'))
            : Column(children: b2b.map((e) => _B2BRow(entry: e as Map<String, dynamic>)).toList()),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'B2C Small (Without GSTIN)',
        subtitle: '${b2cs.length} invoices',
        icon: Icons.person,
        color: AppColors.accent,
        child: b2cs.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Text('No B2C invoices this period'))
            : Column(children: b2cs.map((e) => _B2CRow(entry: e as Map<String, dynamic>)).toList()),
      ),
    ]);
  }
}

class _B2BRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _B2BRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry['partyName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(entry['gstin'] ?? '', style: const TextStyle(fontSize: 12)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(Formatters.currency(entry['taxableAmount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text('Tax: ${Formatters.currency(entry['totalTax'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

class _B2CRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _B2CRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry['invoiceNo'] ?? '', style: const TextStyle(fontSize: 14)),
      subtitle: Text(Formatters.date(entry['date'] != null ? DateTime.parse(entry['date']) : null)),
      trailing: Text(Formatters.currency(entry['totalAmount']), style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _Gstr3bTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Gstr3bTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _SummaryRow('Total Taxable Turnover', Formatters.currency(data['taxableTurnover']), AppColors.primary),
      _SummaryRow('CGST Payable', Formatters.currency(data['cgst']), AppColors.warning),
      _SummaryRow('SGST Payable', Formatters.currency(data['sgst']), AppColors.warning),
      _SummaryRow('IGST Payable', Formatters.currency(data['igst']), AppColors.info),
      _SummaryRow('Cess', Formatters.currency(data['cess']), AppColors.grey600),
      const Divider(height: 24),
      _SummaryRow('Total Tax Liability', Formatters.currency(data['totalTax']), AppColors.error,
          isBold: true, isLarge: true),
    ]);
  }
}

class _HsnSummaryTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HsnSummaryTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final hsn = (data['hsnSummary'] as List?) ?? [];
    if (hsn.isEmpty) return const Center(child: Text('No HSN data for this period'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hsn.length,
      itemBuilder: (ctx, i) {
        final h = hsn[i] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('HSN: ${h['hsnCode']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Qty: ${Formatters.quantity(h['quantity'])}'),
              ]),
              const SizedBox(height: 4),
              Text(h['description'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _HSNCell('Taxable', Formatters.currency(h['taxableAmount'])),
                _HSNCell('CGST', Formatters.currency(h['cgst'])),
                _HSNCell('SGST', Formatters.currency(h['sgst'])),
                _HSNCell('IGST', Formatters.currency(h['igst'])),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _HSNCell extends StatelessWidget {
  final String label, value;
  const _HSNCell(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
  ]);
}

class _SectionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title, required this.subtitle, required this.icon,
    required this.color, required this.child,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Column(children: [
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      ),
      const Divider(height: 1),
      child,
    ]),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isBold, isLarge;

  const _SummaryRow(this.label, this.value, this.color, {this.isBold = false, this.isLarge = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: isLarge ? 16 : 14,
      )),
      Text(value, style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: isLarge ? 18 : 14,
      )),
    ]),
  );
}
