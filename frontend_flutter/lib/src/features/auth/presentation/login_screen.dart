import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../../../core/widgets/uniassist_logo.dart';
import '../application/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _studentIdController = TextEditingController(text: 'STU001');
  final _staffUsernameController = TextEditingController(text: 'registrar_staff');
  bool _isStaffMode = false;
  String _selectedRole = 'Registrar';

  final _staffRoles = const [
    'Registrar',
    'Finance Department',
    'Admission Team',
    'Department Coordinator',
    'Student Services',
  ];

  @override
  void dispose() {
    _studentIdController.dispose();
    _staffUsernameController.dispose();
    super.dispose();
  }

  Future<void> _handleStudentLogin() async {
    final success = await ref.read(authProvider.notifier).login(_studentIdController.text.trim());
    if (success && mounted) context.go('/dashboard');
  }

  Future<void> _handleStaffLogin() async {
    final success = await ref.read(authProvider.notifier).staffLogin(
          _staffUsernameController.text.trim(),
          _selectedRole,
        );
    if (success && mounted) context.go('/staff');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        Expanded(
                          flex: 5,
                          child: _IntroPanel(wide: wide).animate().fadeIn(duration: 350.ms).slideX(begin: -0.03),
                        )
                      else
                        _IntroPanel(wide: wide).animate().fadeIn(duration: 350.ms).slideY(begin: -0.03),
                      SizedBox(width: wide ? 24 : 0, height: wide ? 0 : 24),
                      if (wide)
                        Expanded(
                          flex: 4,
                          child: _LoginPanel(
                            isStaffMode: _isStaffMode,
                            authState: authState,
                            studentIdController: _studentIdController,
                            staffUsernameController: _staffUsernameController,
                            selectedRole: _selectedRole,
                            staffRoles: _staffRoles,
                            onModeChanged: (value) => setState(() => _isStaffMode = value),
                            onRoleChanged: (value) => setState(() => _selectedRole = value),
                            onStudentLogin: _handleStudentLogin,
                            onStaffLogin: _handleStaffLogin,
                          ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideX(begin: 0.03),
                        )
                      else
                        _LoginPanel(
                          isStaffMode: _isStaffMode,
                          authState: authState,
                          studentIdController: _studentIdController,
                          staffUsernameController: _staffUsernameController,
                          selectedRole: _selectedRole,
                          staffRoles: _staffRoles,
                          onModeChanged: (value) => setState(() => _isStaffMode = value),
                          onRoleChanged: (value) => setState(() => _selectedRole = value),
                          onStudentLogin: _handleStudentLogin,
                          onStaffLogin: _handleStaffLogin,
                        ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideX(begin: 0.03),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      minHeight: wide ? 560 : 320,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UniAssistLogo(size: 58, showWordmark: true, wordmarkColor: Colors.white),
          SizedBox(height: wide ? 150 : 60),
          Text(
            'A guided service kiosk for university procedures.',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, height: 1.08),
          ),
          const SizedBox(height: 18),
          Text(
            'Verify once, choose a service, and follow clear steps for documents, requests, grievances, scholarships, academics, and withdrawal guidance.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.82), height: 1.45),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _IntroChip(label: 'Touch-first'),
              _IntroChip(label: 'Privacy reset'),
              _IntroChip(label: 'Staff-ready'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.isStaffMode,
    required this.authState,
    required this.studentIdController,
    required this.staffUsernameController,
    required this.selectedRole,
    required this.staffRoles,
    required this.onModeChanged,
    required this.onRoleChanged,
    required this.onStudentLogin,
    required this.onStaffLogin,
  });

  final bool isStaffMode;
  final AuthState authState;
  final TextEditingController studentIdController;
  final TextEditingController staffUsernameController;
  final String selectedRole;
  final List<String> staffRoles;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onStudentLogin;
  final VoidCallback onStaffLogin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Access UniAssist', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Choose your access mode to continue.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 24),
            _ModeSelector(isStaffMode: isStaffMode, onChanged: onModeChanged),
            const SizedBox(height: 24),
            if (authState.error != null) ...[
              _ErrorBanner(message: authState.error!),
              const SizedBox(height: 16),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isStaffMode
                  ? Column(
                      key: const ValueKey('staff'),
                      children: [
                        TextField(
                          controller: staffUsernameController,
                          enabled: !authState.isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Staff username',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Staff role',
                            prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                          ),
                          items: staffRoles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                          onChanged: authState.isLoading ? null : (value) => onRoleChanged(value ?? selectedRole),
                        ),
                      ],
                    )
                  : TextField(
                      key: const ValueKey('student'),
                      controller: studentIdController,
                      enabled: !authState.isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onStudentLogin(),
                      decoration: const InputDecoration(
                        labelText: 'Student ID',
                        hintText: 'Example: STU001',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: authState.isLoading ? null : (isStaffMode ? onStaffLogin : onStudentLogin),
              icon: authState.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Icon(isStaffMode ? Icons.login_rounded : Icons.touch_app_rounded),
              label: Text(isStaffMode ? 'Open Staff Portal' : 'Start Kiosk Session'),
            ),
            const SizedBox(height: 14),
            Text(
              'The kiosk clears inactive sessions automatically to protect student privacy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.isStaffMode, required this.onChanged});

  final bool isStaffMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _ModeButton(label: 'Student', selected: !isStaffMode, onTap: () => onChanged(false)),
          _ModeButton(label: 'Staff', selected: isStaffMode, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroChip extends StatelessWidget {
  const _IntroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
