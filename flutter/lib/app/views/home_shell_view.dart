import 'mobile_more_view.dart';
import '../../core/widgets/mobile_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_impl.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/app_widgets.dart';
import '../../features/customers/views/customers_list_view.dart';
import '../../features/invoices/views/all_invoices_view.dart';
import '../../features/payments/views/all_payments_view.dart';
import '../../features/settings/views/settings_view.dart';
import 'home_overview_view.dart';
import '../../features/products/views/products_view.dart';
import '../../core/widgets/design_widgets.dart';

/// Adaptive shell that hosts primary navigation:
/// - Mobile   → BottomNavigationBar with Badges
/// - Tablet   → NavigationRail (collapsed) with Badges
/// - Desktop  → NavigationRail (extended) with Badges
class HomeShellView extends StatefulWidget {
  const HomeShellView({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  late int _selectedIndex =
      (Get.arguments is Map ? (Get.arguments as Map)['tab'] as int? : null) ??
      widget.initialIndex;

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const HomeOverviewView();
      case 1:
        return const CustomersListView();
      case 2:
        return const AllInvoicesView();
      case 3:
        return const AllPaymentsView();
      case 4:
        return const SettingsView();
      case 5:
        return const ProductsView();
      case 6:
        return MobileMoreView(onSelect: _onDestinationSelected);
      default:
        return const HomeOverviewView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = DatabaseService.to.dao;

    return StreamBuilder<WorkspaceStats>(
      stream: dao.watchWorkspaceStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;

        return ResponsiveLayout(
          mobile: _MobileShell(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            body: _buildBody(),
            stats: stats,
          ),
          tablet: _RailShell(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            body: _buildBody(),
            extended: false,
            stats: stats,
          ),
          desktop: _RailShell(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            body: _buildBody(),
            extended: true,
            stats: stats,
          ),
        );
      },
    );
  }
}

// ─── Mobile shell ────────────────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    required this.stats,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final WorkspaceStats? stats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MobileBrandHeader(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: designBorder)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _nav(
                'فواتيري',
                Icons.description_outlined,
                selectedIndex == 2,
                () => onDestinationSelected(2),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'إضافة فاتورة',
                  child: InkWell(
                    onTap: () => Get.toNamed(AppRoutes.invoiceCreate),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: designGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'إضافة فاتورة',
                          style: TextStyle(color: designGreen, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _nav(
                'المزيد',
                Icons.grid_view_rounded,
                selectedIndex == 6,
                () => onDestinationSelected(6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(String label, IconData icon, bool selected, VoidCallback tap) =>
      Expanded(
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 35,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE4F6EE)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 25,
                    color: selected ? designGreen : designMuted,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? designGreen : designMuted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── Tablet / Desktop rail shell ─────────────────────────────────────────────

class _RailShell extends StatelessWidget {
  const _RailShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    required this.extended,
    required this.stats,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final bool extended;
  final WorkspaceStats? stats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          DesignSidebar(
            selected: selectedIndex,
            onSelect: onDestinationSelected,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
