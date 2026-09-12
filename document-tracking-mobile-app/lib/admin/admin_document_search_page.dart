import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/background_wrapper.dart';
import '../utils/qr_code_scanning.dart';

import 'admin_document_info_page.dart'; 

class AdminDocumentSearchPage extends StatefulWidget {
  const AdminDocumentSearchPage({
    super.key,
  });

  @override
  State<AdminDocumentSearchPage> createState() => _AdminDocumentSearchPageState();
}

class _AdminDocumentSearchPageState extends State<AdminDocumentSearchPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchCtrl = TextEditingController();
  
  Timer? _debounce;
  String selectedType = 'All';
  final List<String> documentTypes = [
    'All', 'Memorandum', 'Letter', 'Clearance', 'Report', 'Certificate', 'Others',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {}); 
    });
  }

  // UPDATED STREAM FOR ADMIN (No Owner Filter) 
  Stream<List<Map<String, dynamic>>> getDocumentsStream() {
    final keyword = searchCtrl.text.trim().toLowerCase();

    return supabase
        .from('documents')
        .stream(primaryKey: ['document_id'])
        .order('registered_at', ascending: false)
        .map((list) {
          return list.where((doc) {
            final matchesType = selectedType == 'All' || doc['document_type'] == selectedType;
            final matchesKeyword = keyword.isEmpty || 
                doc['document_name'].toString().toLowerCase().contains(keyword) ||
                doc['document_id'].toString().toLowerCase().contains(keyword);
            
            return matchesType && matchesKeyword;
          }).toList();
        });
  }

  Future<void> _handleScannedDocument(String scannedCode) async {
    try {
      final data = await supabase
          .from('documents')
          .select()
          .eq('document_id', scannedCode)
          .maybeSingle();

      if (data == null) {
        if (!mounted) return;
        _showTopNotification("Document not found in database", Colors.red);
        return;
      }

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDocumentInfoPage(
            document: data,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  // HELPER: SHOW TOP SNACKBAR
  void _showTopNotification(String msg, Color color) {
    if (!mounted) return;

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
  }

  // UI COMPONENTS

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 50, 25, 10),
                child: Column(
                  children: [
                    const Text(
                      "Global Search",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Admin access: Search all registered documents",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 12),
                    _buildScanButton(),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildFilterList(),
              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: getDocumentsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF92BC36)));
                    }
                    final results = snapshot.data ?? [];
                    if (results.isEmpty) return _buildEmptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(25, 10, 25, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: results.length,
                      itemBuilder: (context, index) => _buildResultCard(results[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED RESULT CARD
  Widget _buildResultCard(Map<String, dynamic> doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8BB839).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.description_outlined, color: Color(0xFF8BB839), size: 22),
        ),
        title: Text(
          doc['document_name'] ?? 'Untitled',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 15
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: ${doc['document_id']} • ${doc['document_type']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              'Registered by: ${doc['registered_by_id']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF50AB7F), 
                fontSize: 11, 
                fontWeight: FontWeight.w600
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDocumentInfoPage(
                document: doc,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF50AB7F).withOpacity(0.3)),
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search Document ID or Name...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11.5),
          
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF50AB7F), size: 22),
          
          suffixIcon: searchCtrl.text.isNotEmpty
              ? IconButton(
                  padding: const EdgeInsets.all(0),
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                  onPressed: () {
                    searchCtrl.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
              
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 15),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.fromARGB(255, 4, 76, 69),
            Color.fromARGB(255, 119, 150, 52),
            Color.fromARGB(255, 10, 99, 56),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF50AB7F).withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(0, 0),
          )
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        onPressed: () async {
          final String? scannedCode = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRScannerPage()),
          );
          if (scannedCode != null && mounted) _handleScannedDocument(scannedCode);
        },
      ),
    );
  }

  Widget _buildFilterList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: documentTypes.length,
          itemBuilder: (context, index) {
            bool isSelected = selectedType == documentTypes[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(documentTypes[index]),
                selected: isSelected,
                onSelected: (val) => setState(() => selectedType = documentTypes[index]),
                selectedColor: const Color(0xFF50AB7F),
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12),
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 10),
          const Text("No documents found.", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}