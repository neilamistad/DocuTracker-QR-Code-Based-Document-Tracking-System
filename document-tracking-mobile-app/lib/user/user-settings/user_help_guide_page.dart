import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/background_wrapper.dart';

import '../../utils/user_notifications.dart';

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
    return Scaffold(
      body: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(25, 10, 25, 40), 
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
      'title': 'Registration',
      'icon': Symbols.app_registration,
      'steps': [
        'Navigate – Tap the "Add" button in the navigation bar.',
        'Input Details – Enter the Document Name, Type, and/or Other details.',
        'Register – Tap "Register Document" to generate your unique QR label.',
        'Save – Download the generated label as a PDF for future printing.'
      ]
    },
    {
      'title': 'Printing',
      'icon': Symbols.print,
      'steps': [
        'Open File – Open the downloaded PDF containing the QR Code and Document ID.',
        'Connect – Ensure Bluetooth is on and connect to the kiosk thermal printer.',
        'Print – Send the PDF to the printer to generate your physical sticker.',
        'Affix Label – Use a sticky note as a base, then paste the QR sticker on top.'
      ]
    },
    {
      'title': 'Search & Scan',
      'icon': Symbols.search_check,
      'steps': [
        'Search Bar – Type the Document ID or name to quickly find specific records.',
        'Filter Chips – Tap the category chips (e.g., Office, Type) to narrow down results.',
        'View Info – Tap any result card to view its information and full movement logs.',
        'OR Scan QR Code – Tap the Scan icon to use your phone\'s camera for instant searching.'
      ]
    },
    {
      'title': 'Editing',
      'icon': Symbols.edit_document,
      'steps': [
        'Locate – Find the document using the Search or Scan feature.',
        'Edit Mode – Tap the "Pencil Icon" on the Document Info page.',
        'Update – Modify the necessary fields and tap "Save Changes".',
        'Sync – Changes are immediately updated across the system.'
      ]
    },
    {
      'title': 'Deletion',
      'icon': Symbols.delete_forever,
      'steps': [
        'Request – Tap "Delete" on the Document Info page for unwanted records.',
        'Admin Review – Your request will be sent to the Admin queue for approval.',
        'Confirmation – The record is permanently erased once the Admin approves.'
      ]
    },
    {
      'title': 'Security',
      'icon': Symbols.security,
      'steps': [
        'Settings – Navigate to your Account Settings.',
        'Change Password – Enter your current password followed by the new one.',
        'Verify – Save changes and re-login to ensure your account is secure.'
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

              if (showRedDot)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
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