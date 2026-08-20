import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/kiosk_theme.dart';
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

  final _staffRoles = [
    'Registrar',
    'Finance',
    'Admission',
    'Academic Affairs',
    'Student Services',
  ];

  @override
  void dispose() {
    _studentIdController.dispose();
    _staffUsernameController.dispose();
    super.dispose();
  }

  Future<void> _handleStudentLogin() async {
    final success = await ref.read(authProvider.notifier).login(
      _studentIdController.text.trim(),
    );
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _handleStaffLogin() async {
    final success = await ref.read(authProvider.notifier).staffLogin(
      _staffUsernameController.text.trim(),
      _selectedRole,
    );
    if (success && mounted) {
      context.go('/staff');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, minHeight: size.height * 0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Brand header ─────────────────────────
                    _buildBrandHeader(context),
                    const SizedBox(height: 32),

                    // ── Login card ───────────────────────────
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Tab toggle ──────────────────
                            _buildModeToggle(context),
                            const SizedBox(height: 24),

                            // ── Error banner ────────────────
                            if (authState.error != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        authState.error!,
                                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),

                            // ── Form fields ─────────────────
                            if (_isStaffMode) ...[
                              TextField(
                                controller: _staffUsernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Staff Username',
                                  prefixIcon: Icon(Icons.person_outline, size: 28),
                                ),
                                style: const TextStyle(fontSize: 18),
                                enabled: !authState.isLoading,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.badge_outlined, size: 28),
                                ),
                                items: _staffRoles
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                    .toList(),
                                onChanged: authState.isLoading
                                    ? null
                                    : (v) => setState(() => _selectedRole = v!),
                              ),
                            ] else ...[
                              TextField(
                                controller: _studentIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Student ID',
                                  prefixIcon: Icon(Icons.school_outlined, size: 28),
                                  hintText: 'e.g. STU001',
                                ),
                                style: const TextStyle(fontSize: 18),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleStudentLogin(),
                                enabled: !authState.isLoading,
                              ),
                            ],
                            const SizedBox(height: 24),

                            // ── Login button ────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : (_isStaffMode ? _handleStaffLogin : _handleStudentLogin),
                                    child: authState.isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _isStaffMode ? 'Staff Login' : 'Access Kiosk',
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                  ),
                                ),
                                if (authState.token != null) ...[
                                  const SizedBox(width: 16),
                                  IconButton.filledTonal(
                                    iconSize: 28,
                                    padding: const EdgeInsets.all(12),
                                    icon: const Icon(Icons.fingerprint),
                                    onPressed: authState.isLoading
                                        ? null
                                        : () async {
                                            final success = await ref.read(authProvider.notifier).biometricLogin();
                                            if (success && context.mounted) {
                                              context.go(authState.isStaff ? '/staff' : '/dashboard');
                                            }
                                          },
                                    tooltip: 'Biometric Login',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.amityYellow,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.amityYellow.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 44,
            color: AppColors.amityBlue,
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        const Text(
          'UNIASSIST',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 3,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 8),
        Text(
          'Student Service & Procedure Guidance',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w400,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isStaffMode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isStaffMode ? AppColors.amityBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Student',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: !_isStaffMode ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isStaffMode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isStaffMode ? AppColors.amityBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Staff',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isStaffMode ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
