import 'dart:ui';
import 'dart:convert';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:uuid/uuid.dart';

import '../utils/other_office_notification_utils.dart';

import 'offline_queue_page.dart';
import 'verify_document_page.dart';
import 'login_page.dart';

import '../widgets/app_background.dart';

class OtherOfficeMainPage extends StatefulWidget {
  final String officeName;
  final String officeId;

  const OtherOfficeMainPage({
    super.key,
    required this.officeName,
    required this.officeId,
  });

  @override
  State<OtherOfficeMainPage> createState() => _OtherOfficeMainPageState();
}

class _OtherOfficeMainPageState extends State<OtherOfficeMainPage> {
  final supabase = Supabase.instance.client;

  final Stopwatch _scanTimer = Stopwatch();

  final TextEditingController docIdCtrl = TextEditingController();
  final TextEditingController reprintNameCtrl = TextEditingController();
  final TextEditingController reprintDetailsCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();

  final FocusNode scannerFocusNode = FocusNode();
  final FocusNode _qrFocusNode = FocusNode();

  bool isVerifying = false;
  bool isUpdating = false;
  bool isOffline = false;
  int notificationCount = 0;
  String currentDocStatus = 'Received'; 
  StreamSubscription? connectivitySub;

  String selectedStatus = 'Received';
  final List<String> updateStatuses = [
    'Received',
    'For Reviewing',
    'Needs Revision(s)',
    'Signed',
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _initConnectivity();

    OtherOfficeNotificationUtils.syncInitialCount(widget.officeName);
    OtherOfficeNotificationUtils.initializeListener(widget.officeName);

    _setupPushNotifications(); 
  }

  @override
  void dispose() {
    docIdCtrl.dispose();
    reprintNameCtrl.dispose();
    reprintDetailsCtrl.dispose();
    searchCtrl.dispose();
    scannerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        //isOffline = true;
        isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      });
    }
  }

  Future<void> _setupPushNotifications() async {
    try {

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("FCM: Foreground message received!");
        
        OtherOfficeNotificationUtils.syncInitialCount(widget.officeName);

        String title = message.notification?.title ?? message.data['title'] ?? 'CvSU DocuTracker';
        String body = message.notification?.body ?? message.data['body'] ?? 'New update received.';
        
        String fullMessage = "$title: $body";
        debugPrint("Foreground Message: $fullMessage");

        if (mounted) {
          _showTopNotification(
            fullMessage, 
            const Color(0xFF1B5E20),
          );
        }
      });

    } catch (e) {
      debugPrint("Token Sync Error for Push Notification: $e");
    }
  }

  // MAIN UI OF THE APPLICATION
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FULL SCREEN BACKGROUND
          const Positioned.fill(
            child: AppBackground(child: SizedBox.expand()),
          ),

          // SCALABLE UI CONTENT
          LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 1920,
                    height: 1080,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment(-0.5, 0.86),
                              end: Alignment(0.5, -0.86),
                              colors: [
                                Color(0xFF006A60),
                                Color(0xFF92BC36),
                                Color.fromARGB(255, 0, 126, 65),
                              ],
                              stops: [0.16, 0.54, 0.98],
                            ).createShader(bounds);
                          },
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Greetings, ${widget.officeName}!',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 96,
                                  fontFamily: 'Noto Sans Hebrew',
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        const Text(
                          'Choose an action to manage documents',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontFamily: 'Noto Sans Hebrew',
                            fontWeight: FontWeight.w200,
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (isOffline) 
                        _buildOfflineWarningBanner(context),

                        SizedBox(height: isOffline ? 40 : 80),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionCard(
                              title: 'VERIFY DOCUMENT',
                              description: 'Confirm the authenticity and current status of a document.',
                              onTap: showVerifyDocumentPopup,
                            ),
                            const SizedBox(width: 30),
                            _buildActionCard(
                              title: 'UPDATE STATUS',
                              description: 'Modify the current progress or office location of a document.',
                              onTap: showUpdateReupdateStatusPopup,
                            ),
                            const SizedBox(width: 30),
                            _buildActionCard(
                              title: 'REQUEST REPRINT',
                              description: 'Submit a request to generate a new QR code for trackers.',
                              onTap: showRequestReprintPopup,
                            ),
                            const SizedBox(width: 30),
                            ValueListenableBuilder<int>(
                              valueListenable: reprintBadgeNotifier,
                              builder: (context, count, child) {
                                return _buildActionCard(
                                  title: 'VIEW REQUESTS',
                                  description: 'Check the status of your requested QR reprints.',
                                  onTap: () {
                                    showReprintRequestsPopup();
                                  },
                                  badgeCount: count,
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 80),

                        // HELP/GUIDE BUTTON 
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              backgroundColor: Colors.white.withOpacity(0.05),
                            ),
                            onPressed: () {
                              _showHelpGuidePopup();
                            },
                            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF92BC36), size: 30),
                            label: const Text(
                              "HELP & USER GUIDE",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 20,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // LOGOUT BUTTON
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              foregroundColor: Colors.redAccent,
                            ),
                            onPressed: () => _handleLogout(context),
                            icon: const Icon(Icons.logout_rounded, size: 24),
                            label: const Text(
                              "LOGOUT",
                              style: TextStyle(
                                fontSize: 16,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  

  // VERIFY DOCUMENT RELATED BLOCKS:
  Future<void> _verifyDocument() async {
    final docId = docIdCtrl.text.trim();
    if (docId.isEmpty || isVerifying) return;

    setState(() => isVerifying = true);

    try {
      final doc = await supabase
          .from('documents')
          .select('document_id')
          .eq('document_id', docId)
          .maybeSingle();

      if (doc == null) {
        _showTopNotification("Document not found", Colors.redAccent);
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyDocumentPage(documentId: docId),
        ),
      );
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  void showVerifyDocumentPopup() {
    docIdCtrl.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      _qrFocusNode.requestFocus();
    });

    _showSolidDialog(
      title: "Verify Document",
      content: StatefulBuilder(
        builder: (context, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogField(
              focusNode: _qrFocusNode,
              controller: docIdCtrl,
              label: "Document ID",
              icon: Icons.label_outline_rounded,
              onChanged: (_) => setLocal(() {}),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Text(
                "*You can use the QR Code Scanner to auto-fill its Document ID",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF418948),
            foregroundColor: Colors.white,
          ),
          onPressed: _verifyDocument,
          child: const Text("Verify Now"),
        ),
      ],
    );
  }


  // UPDATE & REUPDATE RELATED BLOCKS:
  Future<void> _updateStatus() async {
    final docId = docIdCtrl.text.trim();
    if (docId.isEmpty || isUpdating) return;

    setState(() => isUpdating = true);

    // OFFLINE MODE
    if (isOffline) {
      await _saveUpdateOffline({
        'docId': docId,
        'status': selectedStatus,
        'timestamp': DateTime.now().toIso8601String(),
        'officeName': widget.officeName.toUpperCase(),
      });
      
      if (!mounted) return;
      Navigator.pop(context);
      _showTopNotification("Saved offline. Will sync when online.", Colors.orangeAccent);
      setState(() => isUpdating = false);
      return;
    }

    // ONLINE MODE
    try {
      
      final latest = await supabase
          .from('tracking_history')
          .select('status, office, registered_by_id, registered_by_type')
          .eq('document_id', docId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest != null) {
        String dbStatus = latest['status'];
        
        // DUPLICATE CHECK
        if (latest['office'] == widget.officeName.toUpperCase() && dbStatus == selectedStatus) {
          if (mounted) {
            _showTopNotification("Status already set by your office", Colors.blueGrey);
          }
          return; 
        }

        // ONLINE REGRESSION CHECK
        int dbRank = updateStatuses.indexOf(dbStatus);
        int newRank = updateStatuses.indexOf(selectedStatus);

        if (newRank < dbRank && latest['office'] == widget.officeName.toUpperCase()) {
          if (mounted) {
            _showTopNotification("Error: Cannot revert from $dbStatus to $selectedStatus", Colors.redAccent);
          }
          return; 
        }
      }

      // UPDATE MAIN TABLE
      await supabase.from('documents').update({
        'current_status': selectedStatus
      }).eq('document_id', docId);

      // RECORDING PHASE
      await supabase.from('tracking_history').insert({
        'document_id': docId,
        'status': selectedStatus,
        'office': widget.officeName.toUpperCase(),
        'registered_by_id': latest != null ? latest['registered_by_id'] : widget.officeId,
        'registered_by_type': latest != null ? latest['registered_by_type'] : 'other office',
        'updated_at': DateTime.now().toIso8601String(),
        'is_corrected': false,
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showTopNotification("Status updated online", Colors.green);

    } catch (e) {
      debugPrint("Online Error: $e");
      if (mounted) {
        _showTopNotification("Failed to update status online.", Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _reupdateStatus() async {
    final docId = docIdCtrl.text.trim();
    if (docId.isEmpty || isUpdating) return;

    setState(() => isUpdating = true);

    // OFFLINE MODE
    if (isOffline) {
      await _saveUpdateOffline({
        'docId': docId,
        'status': selectedStatus,
        'timestamp': DateTime.now().toIso8601String(),
        'officeName': widget.officeName.toUpperCase(),
        'is_reupdate': true,  
      });
      
      if (!mounted) return;
      Navigator.pop(context);
      _showTopNotification("Reupdate saved offline. Will sync when online.", Colors.orangeAccent);
      setState(() => isUpdating = false);
      return;
    }

    // ONLINE MODE
    try {
      final history = await supabase
        .from('tracking_history')
        .select('history_id, status')
        .eq('document_id', docId)
        .eq('office', widget.officeName.toUpperCase())
        .order('updated_at', ascending: false);

      if (history.isEmpty) {
        _showTopNotification("No history found for this office.", Colors.orange);
        return;
      }

      int targetIndex = history.indexWhere((item) => item['status'] == selectedStatus);
      
      if (targetIndex == -1) {
        _showTopNotification("The status '$selectedStatus' was never reached by this document.", Colors.orange);
        return;
      }

      // ONFIRMATION DIALOG
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: const Row(
              children: [
                Icon(Icons.history_edu, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text("Confirm Reupdate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("The following updates will be deleted:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 15),

                _buildStatusComparison("CURRENT STATUS (TO DELETE)", history.first['status'], Colors.redAccent),
                
                const SizedBox(height: 15),
                const Center(child: Icon(Icons.keyboard_double_arrow_down, color: Colors.white24)),
                const SizedBox(height: 15),

                _buildStatusComparison("REVERT BACK TO", selectedStatus, const Color(0xFF92BC36)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF418948),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm Reupdate"),
              ),
            ],
          ),
        ),
      );

      if (confirm != true) return;

      // START RPC LOGIC
      List<int> idsToDelete = [];
      final int targetId = history[targetIndex]['history_id'];

      for (int i = 0; i < targetIndex; i++) {
        if (history[i]['history_id'] != targetId) {
          idsToDelete.add(history[i]['history_id']);
        }
      }

      final String nowPHT = DateTime.now().toIso8601String();

      await supabase.rpc('reupdate_document_status', params: {
        'target_history_id': targetId,
        'ids_to_delete': idsToDelete,
        'new_status': selectedStatus,
        'new_updated_at': nowPHT,
        'doc_id': docId,
      });

      if (mounted) {
        docIdCtrl.clear();
        Navigator.pop(context);
        _showTopNotification("Status successfully reverted to \"$selectedStatus\"", Colors.green);
      }

    } catch (e) {
      debugPrint("Reupdate Error: $e");
      if (mounted) _showTopNotification("Failed to reupdate status: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  void showUpdateReupdateStatusPopup() {
    docIdCtrl.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      _qrFocusNode.requestFocus();
    });

    _showSolidDialog(
      title: "Update Status",
      content: StatefulBuilder(
        builder: (context, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogField(
              controller: docIdCtrl,
              focusNode: _qrFocusNode,
              label: "Document ID",
              icon: Icons.label_outline_rounded,
              onChanged: (value) {
                if (value.length == 1 && !_scanTimer.isRunning) {
                  _scanTimer.start();
                }

                if (value.endsWith('\n') || value.length >= 15) {
                  if (_scanTimer.isRunning) {
                    _scanTimer.stop();
                    final int elapsed = _scanTimer.elapsedMilliseconds;
                    
                    print("-----------------------------------------");
                    print("🚀 QR SCAN COMPLETE");
                    print("📄 Document ID: ${value.trim()}");
                    print("⏱️ Input Latency: $elapsed ms");
                    print("🕒 Timestamp: ${DateTime.now().toIso8601String()}");
                    print("-----------------------------------------");
                    
                    _scanTimer.reset();
                  }
                }
                
                setLocal(() {});
              },
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Text(
                "*You can use the QR Code Scanner to auto-fill its Document ID",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1A1A1A)),
              child: DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Select Status",
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: updateStatuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => selectedStatus = v!),
              ),
            ),
          ],
        ),
      ),
      actions: [

        // RE-UPDATE BUTTON
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade900,
            foregroundColor: Colors.white,
          ),
          onPressed: isUpdating ? null : () async {
            if (await _validateDocId()) {
              _reupdateStatus();
            }
          },
          child: isUpdating ? _btnLoading() : const Text("Re-update"),
        ),

        // UPDATE BUTTON
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF418948),
            foregroundColor: Colors.white,
          ),
          onPressed: isUpdating ? null : () async {
            if (await _validateDocId()) {
              _updateStatus();
            }
          },
          child: isUpdating ? _btnLoading() : const Text("Update"),
        ),
      ],
    );
  }

  // Validation if the entered Document ID is valid or not
  Future<bool> _validateDocId() async {
    final inputId = docIdCtrl.text.trim();

    if (inputId.isEmpty) {
      _showTopNotification("Please enter or scan a Document ID.", Colors.red);
      return false;
    }

    if (isOffline) {
      return true;
    }

    setState(() => isUpdating = true);

    try {
      final response = await supabase
          .from('documents') 
          .select('document_id')
          .eq('document_id', inputId)
          .maybeSingle();

      if (response == null) {
        _showTopNotification("Document ID not found in the system.", Colors.red);
        return false;
      }

      return true;
    } catch (e) {
      _showTopNotification("Connection error. Please try again.", Colors.red);
      return false;
    } finally {
      setState(() => isUpdating = false);
    }
  }

  // Reupdate status comparison popup UI
  Widget _buildStatusComparison(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  void showRequestReprintPopup() {
    reprintNameCtrl.clear();
    reprintDetailsCtrl.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      _qrFocusNode.requestFocus();
    });
    
    _showSolidDialog(
      title: "Request QR Reprint",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDialogField(
            controller: reprintNameCtrl,
            focusNode: _qrFocusNode,
            label: "Document Name*", 
            icon: Icons.description
          ),
          const SizedBox(height: 15),
          _buildDialogField(
            controller: reprintDetailsCtrl, 
            label: "Other details of the document", 
            maxLines: 3
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("Cancel", style: TextStyle(color: Colors.white70))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF418948),
            foregroundColor: Colors.white,
          ),
          onPressed: isUpdating ? null : () async {
            final docName = reprintNameCtrl.text.trim();
            final details = reprintDetailsCtrl.text.trim();

            if (docName.isEmpty) {
              _showTopNotification("Please provide the document name.", Colors.red);
              return;
            }

            setState(() => isUpdating = true);

            try {
              bool inserted = false;
              String newRequestId = "";

              while (!inserted) {
                newRequestId = "REP-${DateTime.now().year}-${const Uuid().v4().substring(0, 6).toUpperCase()}";

                try {
                  await supabase.from('qr_reprint_requests').insert({
                    'request_id': newRequestId,
                    'document_name': docName,
                    'other_details': details,
                    'requested_by_office': widget.officeName.toUpperCase(),
                    'status': 'pending',
                    'requested_at': DateTime.now().toIso8601String(),
                    'is_read_admin': false, 
                    'is_read_user': true,
                  });
                  
                  inserted = true;
                } catch (e) {
                  if (e.toString().contains('duplicate key value')) {
                    debugPrint("Collision detected for $newRequestId, retrying...");
                    continue; 
                  }
                  rethrow;
                }
              }

              if (!mounted) return;
              Navigator.pop(context);
              _showTopNotification("Request submitted! ID: $newRequestId", Colors.green);

            } catch (e) {
              debugPrint("Reprint Error: $e");
              _showTopNotification("Failed to submit request. Please try again.", Colors.red);
            } finally {
              if (mounted) setState(() => isUpdating = false);
            }
          },
          child: isUpdating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text("Submit Request"),
        ),
      ],
    );
  }


  // VIEW REQUESTS REPRINT RELATED BLOCKS:
  void showReprintRequestsPopup() {
    searchCtrl.clear();

    _showSolidDialog(
      title: "Reprint Requests",
      content: StatefulBuilder(
        builder: (context, setLocal) {
          return SizedBox(
            width: 600,
            height: 400,
            child: Column(
              children: [

                // SEARCH AREA
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        controller: searchCtrl,
                        label: "Search ID or Document Name",
                        icon: Icons.search,
                        onChanged: (val) => setLocal(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () => setLocal(() {}),
                      icon: const Icon(Icons.manage_search_outlined, color: Color(0xFF78CF4E), size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // LIST AREA
                Expanded(
                  child: FutureBuilder<List>(
                    future: fetchReprintRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text("No records found.", style: TextStyle(color: Colors.white70)));
                      }

                      final query = searchCtrl.text.toLowerCase();
                      final list = snapshot.data!.where((e) {
                        final name = e['document_name'].toString().toLowerCase();
                        final id = e['request_id'].toString().toLowerCase();
                        return name.contains(query) || id.contains(query);
                      }).toList();

                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final item = list[i];
                          final isDone = item['status'] == 'done';
                          final isPending = item['status'] == 'pending';
                          final isRejected = item['status'] == 'rejected';
                          final isApproved = item['status'] == 'approved';
                          final isUnread = item['is_read_user'] == false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: 
                                isApproved ? Colors.blueAccent.withOpacity(0.05) : 
                                isRejected ? Colors.redAccent.withOpacity(0.05) : 
                                isDone ? Colors.greenAccent.withOpacity(0.05) : 
                                Colors.orangeAccent.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: 
                                  isApproved ? Colors.blueAccent.withOpacity(0.5) : 
                                  isRejected ? Colors.redAccent.withOpacity(0.5) : 
                                  isDone ? Colors.greenAccent.withOpacity(0.5) : 
                                  Colors.orangeAccent.withOpacity(0.5),
                              ),
                            ),
                            child: Stack(
                              children: [
                                ListTile(

                                  // CLICKABLE LOGIC
                                  onTap: (!isPending && isUnread) ? () async {
                                    await supabase
                                        .from('qr_reprint_requests')
                                        .update({'is_read_user': true})
                                        .eq('request_id', item['request_id']);

                                    await OtherOfficeNotificationUtils.syncInitialCount(widget.officeName);
                                    setLocal(() {});
                                  } : null,
                                  
                                  title: Text(item['document_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    "Request ID: ${item['request_id']}\nStatus: ${item['status'].toString().toUpperCase()}",
                                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                  ),
                                  trailing: isDone 
                                    ? ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF418948),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          await supabase
                                              .from('qr_reprint_requests')
                                              .update({
                                                'status': 'received_by_office',
                                                'is_read_user': true
                                              })
                                              .eq('request_id', item['request_id']);
                                          
                                          await OtherOfficeNotificationUtils.syncInitialCount(widget.officeName);
                                          setLocal(() {}); 
                                          _showTopNotification("Document received.", Colors.green);
                                        },
                                        child: const Text("Receive"),
                                      )
                                    : Icon(
                                        isPending ? Icons.hourglass_empty : 
                                        isApproved ? Icons.check_circle_outline : 
                                        isRejected ? Icons.do_not_disturb : 
                                        isDone ? Icons.check : null,
                                        color: 
                                          isPending ? Colors.orange : 
                                          isApproved ? Colors.blue : 
                                          isRejected ? Colors.red : 
                                          isDone ? Colors.green : null
                                      ),
                                ),

                                // RED DOT
                                if (isUnread && !isPending)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black26, blurRadius: 4)
                                        ]
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CLOSE", style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Future<List> fetchReprintRequests() async {
    return await supabase
        .from('qr_reprint_requests')
        .select()
        .eq('requested_by_office', widget.officeName.toUpperCase())
        .order('requested_at', ascending: false);
  }


  // HELP & USER GUIDE RELATED BLOCKS:
  void _showHelpGuidePopup() {
    _showSolidDialog(
      title: "System Navigation Guide",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideItem(
            "VERIFY DOCUMENT", 
            "Validate the authenticity and registration details of a document."
          ),
          _buildGuideItem(
            "UPDATE STATUS", 
            "Modify the current tracking phase. Use 'Re-update' to revert to a previous state."
          ),
          _buildGuideItem(
            "QR REPRINT REQUEST", 
            "File a formal request for a new QR code in the event of physical damage or loss."
          ),
          _buildGuideItem(
            "OFFLINE PROTOCOL", 
            "Data is securely stored locally and will automatically synchronize once a stable connection is established."
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "DONE",
            style: TextStyle(
              color: Color(0xFF92BC36), 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "• $title",
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }


  // LOGOUT RELATED BLOCKS:
  void _handleLogout(BuildContext context) {
    _showSolidDialog(
      title: "Confirm Logout",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded, 
              color: Colors.redAccent, 
              size: 40
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Are you sure you want to log out?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white, 
              fontSize: 18, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "This will safely end your current session. You will need to log in again to access the system.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
          ),
        ],
      ),
      actions: [

        // CANCEL BUTTON
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "STAY LOGGED IN", 
            style: TextStyle(color: Colors.white38, letterSpacing: 1.1, fontSize: 12)
          ),
        ),
        const SizedBox(width: 8),

        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.redAccent.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.redAccent, width: 0.5),
            ),
          ),
          onPressed: () async {
            try {
              final allChannels = Supabase.instance.client.getChannels();
              for (var ch in allChannels) {
                await Supabase.instance.client.removeChannel(ch);
              }
              debugPrint("Other Office Cleanup: All realtime channels removed.");
            } catch (e) {
              debugPrint("Other Office Supabase Cleanup Error: $e");
            }

            FocusScope.of(context).unfocus();

            OtherOfficeNotificationUtils.resetAll();

            final prefs = await SharedPreferences.getInstance();

            final String? officeId = prefs.getString('logged_office_id');

            if (officeId != null) {
              try {
                String? currentDeviceToken = await FirebaseMessaging.instance.getToken(
                  vapidKey: "BHZWBDkHQfKqbQg0VzzLZ-DE69fxgBInwDCtRfbqCP8-iTnD4VWnQII-qHqMZQRwve9yOB7cv1VoQG83C2vHjaM"
                );

                if (currentDeviceToken != null) {
                  final response = await Supabase.instance.client
                      .from('other_office_accounts')
                      .select('fcm_token')
                      .eq('office_id', officeId)
                      .maybeSingle();

                  if (response != null && response['fcm_token'] != null) {
                    List<String> tokenList = List<String>.from(response['fcm_token']);
                    
                    if (tokenList.contains(currentDeviceToken)) {
                      tokenList.remove(currentDeviceToken);
  
                      await Supabase.instance.client
                          .from('other_office_accounts')
                          .update({'fcm_token': tokenList})
                          .eq('office_id', officeId);
                      
                      debugPrint("Other Office FCM Token for this device cleared successfully.");
                    }
                  }

                  await FirebaseMessaging.instance.deleteToken();
                }
              } catch (dbError) {
                debugPrint("Other Office Database Token Cleanup Error: $dbError");
              }
            }

            // 5. CLEAR LOCAL SESSION
            await prefs.clear();

            if (!mounted) return;

            // 6. REDIRECT TO USER TYPE SELECTION
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const OtherOfficeLoginPage()), 
              (route) => false
            );
          },
          child: const Text(
            "CONFIRM LOG OUT", 
            style: TextStyle(
              color: Colors.redAccent, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0
            )
          ),
        ),
      ],
    );
  }


  // OFFLINE HANDLING BLOCKS:
  Future<void> _saveUpdateOffline(Map<String, dynamic> data) async {
    final String newStatus = data['status'];
    
    // LOCAL REGRESSION CHECK:
    int currentIndex = updateStatuses.indexOf(currentDocStatus);
    int newIndex = updateStatuses.indexOf(newStatus);

    if (newIndex < currentIndex && data['office'] == widget.officeName.toUpperCase()) {
      if (mounted) {
        _showTopNotification("Cannot revert from $currentDocStatus to $newStatus.", Colors.red);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList('pending_updates') ?? [];
    
    pending.add(jsonEncode(data));
    await prefs.setStringList('pending_updates', pending);
    
    debugPrint("Offline save successful: $newStatus");
  }

  Future<void> _syncOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingStrings = prefs.getStringList('pending_updates') ?? [];
    if (pendingStrings.isEmpty) return;

    List<String> remainingUpdates = [];
    int successCount = 0;

    for (var itemStr in pendingStrings) {
      final item = jsonDecode(itemStr);
      final String docId = item['docId'];
      final String newStatus = item['status'];

      try {
        // To verify if the offline update is a REUPDATE scenario
        final history = await supabase
            .from('tracking_history')
            .select('history_id, status')
            .eq('document_id', docId)
            .eq('office', (item['officeName'] ?? widget.officeName).toString().toUpperCase())
            .order('updated_at', ascending: false);

        if (history.isNotEmpty) {
          int targetIndex = history.indexWhere((h) => h['status'] == newStatus);

          // REUPDATE SCENARIO
          if (targetIndex > 0) { 
            List<int> idsToDelete = [];
            final int targetId = history[targetIndex]['history_id'];

            for (int i = 0; i < targetIndex; i++) {
              idsToDelete.add(history[i]['history_id']);
            }

            await supabase.rpc('reupdate_document_status', params: {
              'target_history_id': targetId,
              'ids_to_delete': idsToDelete,
              'new_status': newStatus,
              'new_updated_at': item['timestamp'],
              'doc_id': docId,
            });

            successCount++;
            continue;
          } 
          
          // REGULAR UPDATE SCENARIO (DUPLICATE CHECK)
          else if (targetIndex == 0) {
            continue;
          }
        }

        // NORMAL FLOW
        final docResponse = await supabase
            .from('documents')
            .select('registered_by_id, registered_by_type')
            .eq('document_id', docId)
            .maybeSingle();

        if (docResponse != null) {
          await supabase.from('documents').update({
            'current_status': newStatus
          }).eq('document_id', docId);

          await supabase.from('tracking_history').insert({
            'document_id': docId,
            'status': newStatus,
            'office': (item['officeName'] ?? widget.officeName).toString().toUpperCase(),
            'updated_at': item['timestamp'],
            'registered_by_id': docResponse['registered_by_id'],
            'registered_by_type': docResponse['registered_by_type'],
            'is_corrected': false,
          });
          successCount++;
        }

      } catch (e) {
        remainingUpdates.add(itemStr);
        debugPrint("Sync Error: $e");
      }
    }

    await prefs.setStringList('pending_updates', remainingUpdates);

    if (!mounted) return;

    if (successCount > 0 && remainingUpdates.isEmpty) {
      _showTopNotification("Successfully synced $successCount offline update(s)!", Colors.green);
    } else if (remainingUpdates.isNotEmpty) {
      _showTopNotification("Some updates failed to sync (${remainingUpdates.length} left).", Colors.red);
    }
  }

  void _initConnectivity() {
    connectivitySub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!mounted) return;

      bool currentlyOffline = results.contains(ConnectivityResult.none) || results.isEmpty;

      if (currentlyOffline && !isOffline) {
        _showConnectionSnackBar("You are offline. Changes will be saved locally.", isError: true);
      } else if (!currentlyOffline && isOffline) {
        _showConnectionSnackBar("Back online! Syncing your data...", isError: false);
        _syncOfflineData();
      }

      setState(() {
        isOffline = currentlyOffline;
      });
      
      debugPrint("Connectivity Status: ${currentlyOffline ? 'OFFLINE' : 'ONLINE'}");
    });
  }

  Widget _buildOfflineWarningBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OfflineQueuePage(
                officeName: widget.officeName,
                officeId: widget.officeId,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You are currently in offline mode",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      "Tap to manage pending updates stored locally",
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
}


  // HELPER SNACKBARS BLOCKS:
  void _showTopNotification(String msg, Color color) {
    if (!mounted) return;

    try {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
        displayDuration: const Duration(seconds: 3),
        curve: Curves.elasticOut, 
        reverseCurve: Curves.linear,
      );
    } catch (e) {
      debugPrint("Snackbar error ignored: $e");
    }
    
  }
  
  void _showConnectionSnackBar(String message, {required bool isError}) {
  if (!mounted) return;

  final overlay = Overlay.of(context);

  showTopSnackBar(
    overlay,
    Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isError ? Colors.redAccent : Colors.green,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.cloud_off : Icons.cloud_done,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    displayDuration: const Duration(seconds: 3),
    curve: Curves.elasticOut,
    reverseCurve: Curves.linear,
  );
}


  // OTHER UI RELATED BLOCKS:
  void _showSolidDialog({
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF78CF4E), width: 1),
        ),
        titlePadding: const EdgeInsets.only(top: 25, left: 20, right: 20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
        content: Container(
          width: 400,
          padding: const EdgeInsets.only(top: 10),
          child: SingleChildScrollView(child: content),
        ),
        actionsPadding: const EdgeInsets.all(20),
        actions: actions ?? [],
      ),
    );
  }

  // Helper para sa TextFields
  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    FocusNode? focusNode,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF92BC36)) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF92BC36)),
        ),
      ),
    );
  }

  // UPDATED Helper Widget
  Widget _buildActionCard({
    required String title,
    required String description,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return SizedBox(
      width: 340,
      height: 447,
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          // GLASS LAYER
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),

          // GRADIENT BORDER
          Positioned.fill(
            child: CustomPaint(
              painter: GradientBorderPainter(
                radius: 20,
                strokeWidth: 3,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE6AD3E),
                    Color(0xFF51AC80),
                    Color(0xFFE6AD3E),
                    Color(0xFF79D24E),
                  ],
                  stops: [0.0, 0.35, 0.59, 1.0],
                ),
              ),
            ),
          ),

          // CONTENT & INTERACTION
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                hoverColor: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26)
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontFamily: 'Noto Sans Hebrew',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // THE RED NOTIFICATION BADGE
          if (badgeCount > 0)
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 35,
                  minHeight: 35,
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
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
    );
  }

  // Simple loading widget for button
  Widget _btnLoading() => const SizedBox(
    width: 20, 
    height: 20, 
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
  );

}

class GradientBorderPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  GradientBorderPainter({required this.radius, required this.strokeWidth, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;
    Paint paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);

    RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}