import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/background_wrapper.dart';

import '../../utils/admin_notifications.dart';

class AdminHelpPage extends StatelessWidget {

  const AdminHelpPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), 
                  children: [
                    _buildSectionTitle("General Guide"),
                    const SizedBox(height: 16),
                    _buildHelpGrid(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Opacity(
      opacity: 0.6,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildHelpGrid(BuildContext context) {
    final List<Map<String, dynamic>> helpItems = [
    {
      'title': 'Universal Search',
      'icon': Icons.manage_search_rounded,
      'steps': const [
        'Access Module – Navigate to the "Document Search" section via navigation header.',
        'Query Parameters – Enter the unique Document ID or formal Document Title.',
        'Refine Results – Utilize the "Filter" dropdown menu to isolate specific data sets.',
        'Data Retrieval – Select the record to review comprehensive metadata and transit history.',
      ],
    },
    {
      'title': 'Credential Management',
      'icon': Symbols.password_rounded,
      'steps': [
        'Locate – Find the document using the Search or Scan feature.',
        'Edit Mode – Tap the "Pencil Icon" on the Document Info page.',
        'Update – Modify the necessary fields and tap "Save Changes".',
        'Sync – Changes are immediately updated across the system.'
      ]
    },
    {
      'title': 'Account Provisioning',
      'icon': Icons.person_add_alt_1_rounded,
      'steps': [
        'Onboarding Queue – Navigate to the "Account Requests" within Admin Settings.',
        'Profile Validation – Review applicant full name, institutional ID, and official email.',
        'Database Reconciliation – Synchronize and verify data against Registrar, HR records, or Department records.',
        'Access Control – Authorize professional roles or deny requests with formal justification.',
      ]
    },
    {
      'title': 'Document Oversighting',
      'icon': Icons.auto_delete_rounded,
      'steps': [
        'Retention Review – Access the "Document Deletion Request" within Admin Settings.',
        'Compliance Audit – Confirm the record does not fall under permanent retention mandates.',
        'Justification Analysis – Evaluate the uploader’s rationale for permanent record removal.',
        'System Execution – Authorize permanent erasure or restore the record to active tracking.',
      ]
    },
    {
      'title': 'QR Reprint Verification',
      'icon': Icons.qr_code_scanner_rounded,
      'steps': [
        'Request Validation – Open the "QR Reprint Requests" panel to view pending faculty submissions.',
        'Metadata Cross-Check – Audit the submitted tracking ID and document name against the system\'s central registry.',
        'Authenticity Match – Verify if the requester’s details align with the original uploader’s credentials in the database.',
        'Status Determination – Approve the reprint to generate a new QR code or Reject if details do not match existing records.',
      ]
    },
  ];

    double cardWidth = (MediaQuery.of(context).size.width - 65) / 2;

    return Center(
      child: Wrap(
        spacing: 15,
        runSpacing: 15,
        alignment: WrapAlignment.center,
        children: helpItems.map((item) {
          return SizedBox(
            width: cardWidth,
            child: AspectRatio(
              aspectRatio: 1.1,
              child: _HelpCard(
                title: item['title'],
                icon: item['icon'],
                steps: item['steps'],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 20, 10),
      child: Row(
        children: [
          _buildNotificationBackButton(context),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Help / Guide",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBackButton(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        adminPasswordRequestNotifier,
        adminQRReprintNotifier,
        adminFacultyRequestNotifier,
        adminDeletionRequestNotifier
      ]),
      builder: (context, child) {
        final bool hasNotif = (adminPasswordRequestNotifier.value > 0) ||
                             (adminDeletionRequestNotifier.value > 0) ||
                             (adminQRReprintNotifier.value > 0) ||
                             (adminQRReprintNotifier.value > 0);

        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
            if (hasNotif)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> steps;

  const _HelpCard({required this.title, required this.icon, required this.steps});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showGuideDialog(context),
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF50AB7F), size: 32),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuideDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: const Color(0xFF0D0D0D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Row(
                children: [
                  Icon(icon, color: const Color(0xFF50AB7F), size: 24),
                  const SizedBox(width: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${e.key + 1}.", style: const TextStyle(color: Color(0xFF50AB7F), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))),
                    ],
                  ),
                )).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("GOT IT", style: TextStyle(color: Color(0xFF50AB7F), fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}