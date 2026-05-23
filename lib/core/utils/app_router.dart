import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/select_business_screen.dart';
import '../../features/auth/presentation/screens/create_business_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/sales/presentation/screens/invoice_list_screen.dart';
import '../../features/sales/presentation/screens/create_invoice_screen.dart';
import '../../features/sales/presentation/screens/invoice_detail_screen.dart';
import '../../features/parties/presentation/screens/party_list_screen.dart';
import '../../features/parties/presentation/screens/add_party_screen.dart';
import '../../features/parties/presentation/screens/party_detail_screen.dart';
import '../../features/inventory/presentation/screens/item_list_screen.dart';
import '../../features/inventory/presentation/screens/add_item_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/reports/presentation/screens/profit_loss_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    GoRoute(
      path: '/otp',
      builder: (ctx, state) => OtpScreen(mobile: state.extra as String),
    ),
    GoRoute(path: '/select-business', builder: (ctx, state) => const SelectBusinessScreen()),
    GoRoute(path: '/create-business', builder: (ctx, state) => const CreateBusinessScreen()),
    GoRoute(path: '/home', builder: (ctx, state) => const HomeScreen()),

    // Sales
    GoRoute(path: '/invoices', builder: (ctx, state) => const InvoiceListScreen()),
    GoRoute(path: '/invoices/create', builder: (ctx, state) => const CreateInvoiceScreen()),
    GoRoute(
      path: '/invoices/:id',
      builder: (ctx, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!),
    ),

    // Parties
    GoRoute(path: '/parties', builder: (ctx, state) => const PartyListScreen()),
    GoRoute(
      path: '/parties/add',
      builder: (ctx, state) => AddPartyScreen(initialType: state.extra as String?),
    ),
    GoRoute(
      path: '/parties/:id',
      builder: (ctx, state) => PartyDetailScreen(partyId: state.pathParameters['id']!),
    ),

    // Inventory
    GoRoute(path: '/items', builder: (ctx, state) => const ItemListScreen()),
    GoRoute(path: '/items/add', builder: (ctx, state) => const AddItemScreen()),
    GoRoute(
      path: '/items/:id/edit',
      builder: (ctx, state) => AddItemScreen(itemId: state.pathParameters['id']),
    ),

    // Reports
    GoRoute(path: '/reports', builder: (ctx, state) => const ReportsScreen()),
    GoRoute(path: '/reports/profit-loss', builder: (ctx, state) => const ProfitLossScreen()),
  ],
  errorBuilder: (ctx, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
);
