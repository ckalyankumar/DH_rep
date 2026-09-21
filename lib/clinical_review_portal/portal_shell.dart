import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review_portal/audit_history_screen.dart';
import 'package:dhealth/clinical_review_portal/dashboard_screen.dart';
import 'package:dhealth/clinical_review_portal/emergency_actions_screen.dart';
import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/review_queue_screen.dart';
import 'package:dhealth/clinical_review_portal/reviewers_screen.dart';
import 'package:flutter/material.dart';

class PortalShell extends StatefulWidget {
  const PortalShell({
    super.key,
    required this.auth,
    required this.service,
    required this.identity,
    required this.isAdmin,
  });

  final PortalAuth auth;
  final ClinicalReviewPortalService service;
  final PortalIdentity identity;
  final bool isAdmin;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationRailDestination>[
      if (widget.isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
      const NavigationRailDestination(
        icon: Icon(Icons.inbox_outlined),
        selectedIcon: Icon(Icons.inbox),
        label: Text('Queue'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.history),
        selectedIcon: Icon(Icons.history),
        label: Text('Audit'),
      ),
      if (widget.isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Reviewers'),
        ),
      if (widget.isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.warning_amber_outlined),
          selectedIcon: Icon(Icons.warning_amber),
          label: Text('Emergency'),
        ),
    ];
    final index = _index.clamp(0, destinations.length - 1);

    final pages = <Widget>[
      if (widget.isAdmin) DashboardScreen(service: widget.service),
      ReviewQueueScreen(
        service: widget.service,
        reviewedBy: widget.identity.actorLabel,
      ),
      AuditHistoryScreen(
        service: widget.service,
        reviewedBy: widget.identity.actorLabel,
      ),
      if (widget.isAdmin) ReviewersScreen(service: widget.service),
      if (widget.isAdmin)
        EmergencyActionsScreen(
          service: widget.service,
          actionBy: widget.identity.actorLabel,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Evidence Review'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '${widget.identity.actorLabel} · ${widget.isAdmin ? 'clinicalAdmin' : 'clinicalReviewer'}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 168,
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[index]),
        ],
      ),
    );
  }
}
