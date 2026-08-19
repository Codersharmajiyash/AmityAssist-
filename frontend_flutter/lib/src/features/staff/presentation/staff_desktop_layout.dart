import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StaffDesktopLayout extends StatelessWidget {
  final Widget child;

  const StaffDesktopLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Menu
          Container(
            width: 250,
            color: const Color(0xFF1B325D), // Amity Blue
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white24)),
                  ),
                  child: Center(
                    child: Text(
                      'Staff Portal',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                _buildMenuItem(context, Icons.queue, 'Clearance Queue', '/staff/clearance'),
                _buildMenuItem(context, Icons.fact_check, 'Document Approvals', '/staff/documents'),
                _buildMenuItem(context, Icons.report_problem, 'Grievances', '/staff/grievances'),
                const Spacer(),
                const Divider(color: Colors.white24),
                _buildMenuItem(context, Icons.logout, 'Logout', '/'),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA), // Light grey background
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      onTap: () {
        context.go(route);
      },
      hoverColor: Colors.white12,
    );
  }
}
