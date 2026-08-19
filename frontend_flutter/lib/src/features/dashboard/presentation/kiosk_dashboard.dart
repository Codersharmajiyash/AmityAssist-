import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KioskDashboard extends StatelessWidget {
  const KioskDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // A touch-first, high contrast UI for kiosks
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: const Text('AmityAssist Kiosk', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B325D), // Amity Blue
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 32),
            onPressed: () => context.go('/'),
            tooltip: 'End Session',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to Student Services',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF1B325D)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap an option below to begin',
                style: TextStyle(fontSize: 24, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: 1.5,
                  children: [
                    _buildKioskCard(
                      context: context,
                      title: 'Withdrawal Wizard',
                      icon: Icons.assignment_return,
                      color: const Color(0xFF1B325D),
                      onTap: () => context.go('/withdrawal'),
                    ),
                    _buildKioskCard(
                      context: context,
                      title: 'File a Grievance',
                      icon: Icons.report_problem,
                      color: const Color(0xFFE53935), // Red
                      onTap: () => context.go('/grievance'),
                    ),
                    _buildKioskCard(
                      context: context,
                      title: 'Academics & Exams',
                      icon: Icons.menu_book,
                      color: const Color(0xFFFFCB05), // Amity Yellow
                      textColor: Colors.black87,
                      onTap: () => context.go('/academics'),
                    ),
                    _buildKioskCard(
                      context: context,
                      title: 'Scholarship Hub',
                      icon: Icons.school,
                      color: const Color(0xFF43A047), // Green
                      onTap: () => context.go('/scholarship'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKioskCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.white,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: textColor),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
