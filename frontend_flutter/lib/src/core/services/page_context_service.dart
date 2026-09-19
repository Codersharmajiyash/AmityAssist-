import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the active screen context known to the AI assistant
/// without exposing sensitive student PII.
@immutable
class PageContextState {
  final String route;
  final String screenName;
  final List<String> availableActions;
  final String? primaryAction;

  const PageContextState({
    required this.route,
    required this.screenName,
    required this.availableActions,
    this.primaryAction,
  });

  Map<String, dynamic> toJson() => {
        'route': route,
        'screen_name': screenName,
        'available_actions': availableActions,
        if (primaryAction != null) 'primary_action': primaryAction,
      };

  factory PageContextState.fromRoute(String route) {
    if (route.contains('withdrawal')) {
      return const PageContextState(
        route: '/withdrawal',
        screenName: 'Program Withdrawal Portal',
        availableActions: [
          'Initiate Withdrawal Request',
          'Review Refund Policy',
          'Contact Counselor',
          'Download Clearance Checklist'
        ],
        primaryAction: 'Initiate Withdrawal Request',
      );
    } else if (route.contains('academics')) {
      return const PageContextState(
        route: '/academics',
        screenName: 'Academics & Examination Registry',
        availableActions: [
          'Register for Backpaper Exam',
          'Download Grade Cards',
          'Request Duplicate Marksheet',
          'Apply for Re-evaluation'
        ],
        primaryAction: 'Register for Backpaper Exam',
      );
    } else if (route.contains('forms')) {
      return const PageContextState(
        route: '/forms',
        screenName: 'Institutional Forms & Applications Catalog',
        availableActions: [
          'Hostel Allotment Application',
          'Bonafide Certificate Request',
          'Fee Concession Form',
          'Identity Card Replacement'
        ],
        primaryAction: 'Bonafide Certificate Request',
      );
    } else if (route.contains('scholarship')) {
      return const PageContextState(
        route: '/scholarships',
        screenName: 'Merit & Need Scholarships Portal',
        availableActions: [
          'Apply for Merit Scholarship',
          'Upload Income Certificate',
          'Check Disbursement Status'
        ],
        primaryAction: 'Apply for Merit Scholarship',
      );
    } else if (route.contains('staff')) {
      return const PageContextState(
        route: '/staff',
        screenName: 'Registrar Staff Desk & Decision Registry',
        availableActions: [
          'Review Disciplinary Notesheet',
          'Scan Physical Document (OCR)',
          'Filter Pending Approvals'
        ],
        primaryAction: 'Review Disciplinary Notesheet',
      );
    }

    return const PageContextState(
      route: '/dashboard',
      screenName: 'Student Services Kiosk Dashboard',
      availableActions: [
        'Explore Services Catalog',
        'Check Active Request Status',
        'Ask Digital Counselor',
        'Switch Language / Theme'
      ],
      primaryAction: 'Explore Services Catalog',
    );
  }
}

class PageContextNotifier extends StateNotifier<PageContextState> {
  PageContextNotifier() : super(PageContextState.fromRoute('/dashboard'));

  void setRoute(String route) {
    state = PageContextState.fromRoute(route);
  }

  void updateContext({
    required String screenName,
    required List<String> availableActions,
    String? primaryAction,
  }) {
    state = PageContextState(
      route: state.route,
      screenName: screenName,
      availableActions: availableActions,
      primaryAction: primaryAction,
    );
  }
}

final pageContextProvider =
    StateNotifierProvider<PageContextNotifier, PageContextState>((ref) {
  return PageContextNotifier();
});

/// Provides current button/action target to pulse highlight on screen
class HighlightNotifier extends StateNotifier<String?> {
  HighlightNotifier() : super(null);

  void triggerHighlight(String actionId) {
    state = actionId;
    Future.delayed(const Duration(seconds: 4), () {
      if (state == actionId) {
        state = null;
      }
    });
  }

  void clear() {
    state = null;
  }
}

final buttonHighlightProvider =
    StateNotifierProvider<HighlightNotifier, String?>((ref) {
  return HighlightNotifier();
});
