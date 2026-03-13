import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/admin_controller.dart';
import '../../core/admin_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AdminController>(context);

    return Container(
      width: 260,
      decoration: const BoxDecoration(
          color: AdminTheme.midnightBlack,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(2, 0))]
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      gradient: AdminTheme.orangeGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AdminTheme.merchantOrange.withOpacity(0.4), blurRadius: 12)]
                  ),
                  child: const Icon(FontAwesomeIcons.utensils, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text("ShareBite", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text("ADMIN CONSOLE", style: GoogleFonts.inter(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildNavItem("Dashboard", FontAwesomeIcons.chartLine, AdminPage.dashboard, controller),
                const SizedBox(height: 16),

                _buildSectionHeader("ANALYTICS"), // NEW SECTION
                _buildNavItem("Detailed Reports", FontAwesomeIcons.chartPie, AdminPage.detailedReports, controller), // NEW LINK

                const SizedBox(height: 16),
                _buildSectionHeader("MANAGEMENT"),
                _buildNavItem("Users Database", FontAwesomeIcons.users, AdminPage.users, controller),
                _buildNavItem("Suspended List", FontAwesomeIcons.ban, AdminPage.banned, controller),

                const SizedBox(height: 16),
                _buildSectionHeader("CONTENT"),
                _buildNavItem("Reports & Issues", FontAwesomeIcons.flag, AdminPage.reports, controller),
                _buildNavItem("Food Listings", FontAwesomeIcons.burger, AdminPage.listings, controller),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text("Secure Logout", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text("v1.0.0+1", style: TextStyle(color: Colors.grey.shade800, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildNavItem(String title, IconData icon, AdminPage page, AdminController controller) {
    final isSelected = controller.currentPage == page;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.navigateTo(page),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? AdminTheme.merchantOrange : Colors.grey),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}