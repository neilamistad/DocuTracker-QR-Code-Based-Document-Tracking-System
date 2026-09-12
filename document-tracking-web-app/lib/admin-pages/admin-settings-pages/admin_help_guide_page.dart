import 'package:flutter/material.dart';
import '../../widgets/app_background.dart';
import '../../utils/admin_notification_utils.dart';

class AdminHelpGuidePage extends StatelessWidget {
  const AdminHelpGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDesktop),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 60 : 15, 
                    vertical: isDesktop ? 40 : 20
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Wrap(
                        spacing: isDesktop ? 20 : 12,
                        runSpacing: isDesktop ? 20 : 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _HelpCard(
                            title: 'Universal Document Search',
                            icon: Icons.manage_search_rounded,
                            steps: const [
                              'Access Module – Navigate to the "Document Search" section via navigation header.',
                              'Query Parameters – Enter the unique Document ID or formal Document Title.',
                              'Refine Results – Utilize the "Filter" dropdown menu to isolate specific data sets.',
                              'Data Retrieval – Select the record to review comprehensive metadata and transit history.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Credential Management',
                            icon: Icons.password_rounded,
                            steps: const [
                              'Security Oversight – Open the "Password Change Requests" within Admin Settings.',
                              'Identity Verification – Cross-reference User IDs with the database and perform direct verification.',
                              'Credential Update – Select "Confirm Update" to securely overwrite existing security hashes.',
                              'Audit Confirmation – System generates an automated security alert to the account holder.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Account Provisioning',
                            icon: Icons.person_add_alt_1_rounded,
                            steps: const [
                              'Onboarding Queue – Navigate to the "Account Requests" within Admin Settings.',
                              'Profile Validation – Review applicant full name, institutional ID, and official email.',
                              'Database Reconciliation – Synchronize and verify data against Registrar, HR records, or Department records.',
                              'Access Control – Authorize professional roles or deny requests with formal justification.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Document Oversighting',
                            icon: Icons.auto_delete_rounded,
                            steps: const [
                              'Retention Review – Access the "Document Deletion Request" within Admin Settings.',
                              'Compliance Audit – Confirm the record does not fall under permanent retention mandates.',
                              'Justification Analysis – Evaluate the uploader’s rationale for permanent record removal.',
                              'System Execution – Authorize permanent erasure or restore the record to active tracking.',
                            ],
                          ),
                          _HelpCard(
                            title: 'QR Reprint Verification',
                            icon: Icons.qr_code_scanner_rounded,
                            steps: const [
                              'Request Validation – Open the "QR Reprint Requests" panel to view pending faculty submissions.',
                              'Metadata Cross-Check – Audit the submitted tracking ID and document name against the system\'s central registry.',
                              'Authenticity Match – Verify if the requester’s details align with the original uploader’s credentials in the database.',
                              'Status Determination – Approve the reprint to generate a new QR code or Reject if details do not match existing records.',
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.only(
        top: isDesktop ? 40 : 20, 
        left: isDesktop ? 40 : 15, 
        right: isDesktop ? 40 : 15, 
        bottom: 10
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([
                  adminPasswordRequestNotifier,
                  adminDeletionRequestNotifier,
                  adminQRReprintNotifier,
                  adminFacultyRequestNotifier,
                ]),
                builder: (context, child) {
                  final bool hasNotification = (adminPasswordRequestNotifier.value > 0) || 
                                               (adminDeletionRequestNotifier.value > 0) || 
                                               (adminQRReprintNotifier.value > 0) || 
                                               (adminFacultyRequestNotifier.value > 0);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (hasNotification)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      "Admin Management Guide", 
                      style: TextStyle(
                        fontSize: isDesktop ? 50 : 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40), 
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Operational workflows and administrative oversight procedures',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70, 
              fontSize: isDesktop ? 16 : 13
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> steps;

  const _HelpCard({
    required this.title,
    required this.icon,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;
    
    final double cardWidth = isDesktop ? 280 : (screenWidth * 0.80);
    final double cardHeight = isDesktop ? 180 : 150;

    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        _showGuide(context);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF50AB7F), size: isDesktop ? 45 : 35),
            const SizedBox(height: 12),
            SizedBox(
              width: cardWidth - 20,
              child: isDesktop 
                ? Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 17, 
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      alignment: Alignment.center,
                      constraints: BoxConstraints(minWidth: cardWidth - 20),
                      child: Text(
                        title,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 14, 
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF00120A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF50AB7F)),
        ),
        title: Row(
          children: [
            Icon(icon, color: const Color(0xFF50AB7F)),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Text(
                  title, 
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: steps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF50AB7F),
                          child: Text(
                            '${entry.key + 1}', 
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value, 
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 14,
                              height: 1.4,
                            )
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close', 
              style: TextStyle(color: Color(0xFF50AB7F), fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ),
        ],
      ),
    );
  }
}