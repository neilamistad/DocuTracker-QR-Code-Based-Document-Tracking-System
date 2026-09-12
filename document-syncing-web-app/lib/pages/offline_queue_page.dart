import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_background.dart';

class OfflineQueuePage extends StatefulWidget {
  final String officeName;
  final String officeId;

  const OfflineQueuePage({
    super.key,
    required this.officeName,
    required this.officeId,
  });

  @override
  State<OfflineQueuePage> createState() => _OfflineQueuePageState();
}

class _OfflineQueuePageState extends State<OfflineQueuePage> {
  List<Map<String, dynamic>> _officePending = [];
  List<Map<String, dynamic>> _filteredPending = [];
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  String _formatDateTime(String isoString) {
    try {
      DateTime dt = DateTime.parse(isoString);
      List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      String month = months[dt.month - 1];
      String day = dt.day.toString().padLeft(2, '0');
      String year = dt.year.toString();
      
      int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      String amPm = dt.hour >= 12 ? 'PM' : 'AM';
      String minute = dt.minute.toString().padLeft(2, '0');
      String second = dt.second.toString().padLeft(2, '0');

      return "$month $day, $year | ${hour.toString().padLeft(2, '0')}:$minute:$second $amPm";
    } catch (e) {
      return isoString;
    }
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedList = prefs.getStringList('pending_updates') ?? [];
    
    List<Map<String, dynamic>> allPending = encodedList
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    setState(() {
      _officePending = allPending.where((item) => 
        item['officeName'] == widget.officeName.toUpperCase()
      ).toList();

      _officePending.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      _filteredPending = _officePending;
      _isLoading = false;
    });
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredPending = _officePending
          .where((item) => item['docId']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _deleteEntry(int indexInFiltered) async {
    final itemToDelete = _filteredPending[indexInFiltered];
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedList = prefs.getStringList('pending_updates') ?? [];
    
    List<Map<String, dynamic>> allData = encodedList
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();

    allData.removeWhere((item) => 
      item['docId'] == itemToDelete['docId'] && 
      item['timestamp'] == itemToDelete['timestamp'] &&
      item['officeName'] == widget.officeName.toUpperCase()
    );

    await prefs.setStringList('pending_updates', allData.map((e) => jsonEncode(e)).toList());
    _loadQueue();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomAppBar(context),
              _buildSearchBar(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                child: Text(
                  "Pending Sync Records",
                  style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                    : _filteredPending.isEmpty
                        ? _buildEmptyState()
                        : _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 25, top: 20, bottom: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Offline Queue",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.officeName,
                style: const TextStyle(color: Color(0xFF78CF4E), fontSize: 13, letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _filterSearch,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search Document ID...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF50AB7F), size: 20),
          filled: true,
          fillColor: Colors.black.withOpacity(0.4),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF78CF4E), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      itemCount: _filteredPending.length,
      separatorBuilder: (_, _) => const SizedBox(height: 15),
      itemBuilder: (context, index) {
        final item = _filteredPending[index];
        final bool isReupdate = item['is_reupdate'] ?? false;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.label_outline_rounded, color: Color(0xFF78CF4E), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['docId'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                letterSpacing: 1.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Status: ${item['status']}",
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.white24, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(item['timestamp']),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBadge(isReupdate),
                    const SizedBox(width: 8),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                      onPressed: () => _deleteEntry(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(bool isReupdate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
        color: isReupdate ? Colors.orange.withOpacity(0.15) : const Color(0xFF78CF4E).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReupdate ? Colors.orange.withOpacity(0.5) : const Color(0xFF78CF4E).withOpacity(0.5),
          width: 1
        ),
      ),
      child: Text(
        isReupdate ? "RE-UPDATE" : "UPDATE",
        style: TextStyle(
          color: isReupdate ? Colors.orange : const Color(0xFF78CF4E),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            "No pending local updates", 
            style: TextStyle(color: Colors.white24, fontSize: 14, letterSpacing: 0.5)
          ),
        ],
      ),
    );
  }
}