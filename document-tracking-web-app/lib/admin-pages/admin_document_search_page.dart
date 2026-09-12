import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_document_info_page.dart';

class AdminDocumentSearchPage extends StatefulWidget {
  const AdminDocumentSearchPage({super.key});

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

  Stream<List<Map<String, dynamic>>> getAdminDocumentsStream() {
    final keyword = searchCtrl.text.trim().toLowerCase();

    return supabase
        .from('documents')
        .stream(primaryKey: ['document_id'])
        .map((list) {
          return list.where((doc) {
            final matchesType = selectedType == 'All' || doc['document_type'] == selectedType;
            final matchesKeyword = keyword.isEmpty || 
                doc['document_name'].toString().toLowerCase().contains(keyword) ||
                doc['document_id'].toString().toLowerCase().contains(keyword);
            
            return matchesType && matchesKeyword;
          }).toList()..sort((a, b) => b['registered_at'].compareTo(a['registered_at']));
        });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final bool isDesktop = availableWidth > 1000;

        Widget topSection = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40 : 20,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: Column(
              children: [
                _buildHeaderSection(availableWidth),
                const SizedBox(height: 30),
                _buildSearchInput(isDesktop),
                const SizedBox(height: 10),
                _buildFilterSection(),
              ],
            ),
          ),
        );

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: getAdminDocumentsStream(),
          builder: (context, snapshot) {
            final results = snapshot.data ?? [];
            final bool isLoading = snapshot.connectionState == ConnectionState.waiting;

            if (isDesktop) {
              return Column(
                children: [
                  topSection,
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                        : results.isEmpty
                            ? const Center(
                                child: Text(
                                  'No documents found',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 18,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              )
                            : Container(
                                width: double.infinity,
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1150),
                                  child: _buildResultsList(true, results),
                                ),
                              ),
                  ),
                  const SizedBox(height: 50),
                ],
              );
            } else {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    topSection,
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
                      )
                    else if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Text('No documents found', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1150),
                        child: _buildResultsList(false, results),
                      ),
                    const SizedBox(height: 50),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  // UI COMPONENTS (DESIGN INTACT)

  Widget _buildSearchInput(bool isDesktop) {
    return Container(
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x14D9D9D9),
        borderRadius: BorderRadius.circular(2300),
        border: Border.all(color: const Color(0xFF50AB7F), width: 1.2),
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: _onSearchChanged,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.0),
        decoration: InputDecoration(
          hintText: 'Search Document ID or Name...',
          hintStyle: TextStyle(color: Color(0x99D9D9D9), fontSize: isDesktop ? 15 : 13, height: 1.0),
          border: InputBorder.none,
          isCollapsed: true, 
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 20, right: 10),
            child: Icon(Icons.search, color: Color(0xFF50AB7F), size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: EdgeInsets.only(top: isDesktop ? 20 : 15, bottom: isDesktop ? 20 : 15, right: isDesktop ? 20 : 10),
          suffixIcon: searchCtrl.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38, size: 20),
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

  Widget _buildFilterSection() {
    return Row(
      children: [
        const Text('Filter:   ', style: TextStyle(color: Color(0x99D9D9D9), fontSize: 15)),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedType,
            dropdownColor: const Color(0xFF00120A),
            items: documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (val) {
              setState(() => selectedType = val!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(bool isDesktop, List<Map<String, dynamic>> results) {
    return ListView.separated(
      shrinkWrap: !isDesktop, 
      physics: isDesktop 
          ? const AlwaysScrollableScrollPhysics() 
          : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 20, vertical: 10),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _documentCard(results[index]),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminDocumentInfoPage(document: doc))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['document_name'] ?? 'No Name',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text('ID: ${doc['document_id']}  •  Type: ${doc['document_type']}', style: const TextStyle(color: Color(0x99D9D9D9), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(double screenWidth) {
    return Column(
      children: [
        Text(
          'Admin Search',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth > 600 ? 70 : 35,
            fontFamily: 'Noto Sans Hebrew',
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text('Search all documents registered across the system', style: TextStyle(color: Colors.white70, fontSize: 16)),
      ],
    );
  }
}