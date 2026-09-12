import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'document_info_page.dart';

class DocumentSearchPage extends StatefulWidget {
  final String userType;
  final String userId;

  const DocumentSearchPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<DocumentSearchPage> createState() => _DocumentSearchPageState();
}

class _DocumentSearchPageState extends State<DocumentSearchPage> {
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

  // AUTO SEARCH LOGIC
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {}); 
    });
  }

  // REAL-TIME STREAM LOGIC
  Stream<List<Map<String, dynamic>>> getDocumentsStream() {
    final keyword = searchCtrl.text.trim().toLowerCase();

    return supabase
        .from('documents')
        .stream(primaryKey: ['document_id'])
        .order('registered_at', ascending: false)
        .map((list) {
          return list.where((doc) {
            
            final isOwner = doc['registered_by_id'] == widget.userId;
            final matchesType = selectedType == 'All' || doc['document_type'] == selectedType;
            final matchesKeyword = keyword.isEmpty || 
                doc['document_name'].toString().toLowerCase().contains(keyword) ||
                doc['document_id'].toString().toLowerCase().contains(keyword);
            
            return isOwner && matchesType && matchesKeyword;
          }).toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 1100;

    Widget buildHeader() => Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 25, vertical: 20),
      child: Column(
        children: [
          _buildHeaderTitle(screenWidth),
          const SizedBox(height: 30),
          _buildSearchInput(isDesktop),
          const SizedBox(height: 15),
          _buildFilterDropdown(),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: getDocumentsStream(),
          builder: (context, snapshot) {
            final results = snapshot.data ?? [];
            final bool isLoading = snapshot.connectionState == ConnectionState.waiting;

            if (isDesktop) {
              return Column(
                children: [
                  buildHeader(),
                  Expanded(
                    child: Column(
                      children: [
                        if (isLoading)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
                            ),
                          )
                        else if (results.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                'No documents found',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 18,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(child: _buildResultsList(true, results)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              );
            }else {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildHeader(),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
                      )
                    else if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Text('No documents found', style: TextStyle(color: Colors.white38)),
                      )
                    else
                      _buildResultsList(false, results),
                    const SizedBox(height: 50),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildSearchInput(bool isDesktop) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF50AB7F), width: 1.2),
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search Document ID or Name...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: isDesktop ? 15 : 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF50AB7F)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: isDesktop ? 20 : 15, bottom: isDesktop ? 20 : 15, right: isDesktop ? 20 : 10),
          suffixIcon: searchCtrl.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38),
                onPressed: () {
                  searchCtrl.clear();
                  _onSearchChanged('');
                },
              ) 
            : null,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Row(
      children: [
        const Text('Document Type: ', style: TextStyle(color: Colors.white60)),
        const SizedBox(width: 10),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedType,
            dropdownColor: const Color(0xFF121212),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) {
              setState(() => selectedType = val!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTitle(double screenWidth) {
    return Column(
      children: [
        Text(
          'Find Documents',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth > 600 ? 75 : 35,
            fontFamily: 'Noto Sans Hebrew',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quickly find any document stored in the system',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300),
        ),
      ],
    );
  }

  Widget _buildResultsList(bool isDesktop, List<Map<String, dynamic>> results) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20, vertical: 10),
      shrinkWrap: !isDesktop, 
      physics: isDesktop 
          ? const BouncingScrollPhysics() 
          : const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _buildResultCard(results[index]);
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          doc['document_name'] ?? 'Untitled',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis
        ),
        subtitle: Text(
          'ID: ${doc['document_id']} • ${doc['document_type']}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF78CF4E)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentInfoPage(
                document: doc,
                userType: widget.userType,
                userId: widget.userId,
              ),
            ),
          );
        },
      ),
    );
  }
}