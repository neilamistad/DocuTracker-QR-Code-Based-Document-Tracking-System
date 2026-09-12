import 'package:flutter/material.dart';
import '../../widgets/app_background.dart';
import '../../utils/notification_utils.dart';

class UserHelpPage extends StatelessWidget {
  final String userId;
  final String userType;

  const UserHelpPage({
    super.key,
    required this.userId,
    required this.userType,
  });

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
                    vertical: isDesktop ? 40 : 20,
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
                            title: 'Document Registration',
                            icon: Icons.app_registration,
                            steps: const [
                              'Navigate to Registration – Click "Document Registration" tab.',
                              'Input Metadata – Fill in Name, Category, and Recipient.',
                              'Register & Generate – Click "Register Document" to get your QR label.',
                              'Download – Save the label as a PDF for printing.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Labeling & Printing',
                            icon: Icons.print_rounded,
                            steps: const [
                              'Open PDF – Open your downloaded label file.',
                              'Thermal Print – Print using the kiosk printer.',
                              'Prepare Base – Use a Sticky Note as a protective layer.',
                              'Affix Label – Paste the QR sticker on top of the sticky note.',
                              'Quality Check – Ensure the QR is flat and scannable.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Search (Desktop/Kiosk)',
                            icon: Icons.desktop_windows_rounded,
                            steps: const [
                              'Focus Input – Click the search bar first.',
                              'Wired Scanner – Use the Wired QR Code Scanner to instantly input the ID.',
                              'Filter – Use dropdowns to narrow results.',
                              'View – Click result cards for full history.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Search (Mobile)',
                            icon: Icons.edgesensor_high_rounded,
                            steps: const [
                              'Track Document – Enter the Document ID to see its current status.',
                              'Manual Entry – Type the unique ID code from your physical document.',
                              'Real-time Updates – Instantly view the latest logs and location of your file.',
                              'Quick Search – Get immediate results with our optimized tracking system.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Editing & Fixes',
                            icon: Icons.edit_document,
                            steps: const [
                              'Locate – Find the document via search.',
                              'Edit Mode – Click the pencil icon in the Info Page.',
                              'Save Changes – Updates are reflected immediately.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Deletion Requests',
                            icon: Icons.delete_forever_rounded,
                            steps: const [
                              'Locate – Find the document via search.',
                              'Request – Click "Delete" in Document Info Page.',
                              'Admin Queue – Request is sent for Admin review.',
                              'Approval – Once approved, record is permanently erased.',
                            ],
                          ),
                          _HelpCard(
                            title: 'Account Security',
                            icon: Icons.security_rounded,
                            steps: const [
                              'Access Settings – Go to Account Settings.',
                              'Update – Enter current and new password.',
                              'Confirm – Save and re-login to verify.',
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
        bottom: 10,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([
                  trackingBadgeNotifier,
                  deletionBadgeNotifier,
                  passwordRequestStatusNotifier
                ]),
                builder: (context, child) {
                  final bool hasCounts = trackingBadgeNotifier.value > 0 || deletionBadgeNotifier.value > 0;
                  final passwordData = passwordRequestStatusNotifier.value;
                  final bool hasUnreadPassword = passwordData != null &&
                      passwordData['is_read_user'] == false &&
                      passwordData['status'] != 'pending';

                  final bool showRedDot = hasCounts || hasUnreadPassword;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (showRedDot)
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
                  child: Text(
                    "System Help & Guide",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 24 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a category to learn how to use the system features',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isDesktop ? 16 : 13,
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
      onTap: () => _showGuide(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF50AB7F), size: isDesktop ? 45 : 35),
            const SizedBox(height: 15),

            SizedBox(
              width: cardWidth - 20,
              child: isDesktop 
                ? Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      constraints: BoxConstraints(minWidth: cardWidth - 20),
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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

        // RESPONSIVE SCROLLABLE TITLE
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
                  ),
                ),
              ),
            ),
          ],
        ),

        // RESPONSIVE SCROLLABLE CONTENT ---
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
                            style: const TextStyle(
                              fontSize: 11, 
                              color: Colors.white, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 15, 
                              height: 1.4
                            ),
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
              style: TextStyle(
                color: Color(0xFF50AB7F), 
                fontWeight: FontWeight.bold,
                fontSize: 16
              ),
            ),
          ),
        ],
      ),
    );
  }
}