import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/admin_controller.dart';
import '../../core/admin_theme.dart';
import 'side_menu.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/users/users_page.dart';
import '../pages/users/banned_users_page.dart';
import '../pages/reports/reports_page.dart';
import '../pages/listings/listings_page.dart';
import '../pages/reports/detailed_report_page.dart';

class AdminLayout extends StatelessWidget {
  const AdminLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.backgroundGrey,
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width > 900)
            const SideMenu(),
          Expanded(
            child: Column(
              children: [
                if (MediaQuery.of(context).size.width <= 900)
                  AppBar(
                    backgroundColor: AdminTheme.midnightBlack,
                    iconTheme: const IconThemeData(color: Colors.white),
                    elevation: 0,
                    title: const Text("ShareBite Admin", style: TextStyle(color: Colors.white)),
                  ),

                Expanded(child: _MainContent()),
              ],
            ),
          ),
        ],
      ),
      drawer: MediaQuery.of(context).size.width <= 900 ? const SideMenu() : null,
    );
  }
}

class _MainContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AdminController>(context);

    Widget getPage() {
      switch (controller.currentPage) {
        case AdminPage.dashboard: return const DashboardPage();
        case AdminPage.detailedReports: return const DetailedReportPage(); // This now works
        case AdminPage.users: return const UsersPage();
        case AdminPage.banned: return const BannedUsersPage();
        case AdminPage.reports: return const ReportsPage();
        case AdminPage.listings: return const ListingsPage();
        default: return const DashboardPage();
      }
    }

    return Container(
      color: AdminTheme.backgroundGrey,
      child: getPage(),
    );
  }
}