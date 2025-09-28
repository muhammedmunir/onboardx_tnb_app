import 'package:flutter/material.dart';

class OrganizationChartScreen extends StatefulWidget {
  const OrganizationChartScreen({super.key});

  @override
  State<OrganizationChartScreen> createState() => _OrganizationChartScreenState();
}

class _OrganizationChartScreenState extends State<OrganizationChartScreen> {
  final TextEditingController _searchCtr = TextEditingController();
  final ScrollController _scrollCtr = ScrollController();
  String _query = '';
  String _filter = 'All';
  bool _compact = false;
  bool _showScrollTop = false;
  final Color _accentColor = const Color.fromRGBO(224, 124, 124, 1);

  @override
  void initState() {
    super.initState();
    _searchCtr.addListener(() => setState(() => _query = _searchCtr.text.trim().toLowerCase()));
    _scrollCtr.addListener(() {
      if (_scrollCtr.offset > 220 && !_showScrollTop) setState(() => _showScrollTop = true);
      if (_scrollCtr.offset <= 220 && _showScrollTop) setState(() => _showScrollTop = false);
    });
  }

  @override
  void dispose() {
    _searchCtr.dispose();
    _scrollCtr.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredTeam {
    final q = _query;
    return _teamMembers.where((m) {
      if (_filter != 'All') {
        final f = _filter.toLowerCase();
        if (!m['role']!.toLowerCase().contains(f) && !m['role']!.toLowerCase().contains(f == 'manager' ? 'manager' : f)) return false;
      }
      if (q.isEmpty) return true;
      return ('${m['name']!} ${m['role']!}').toLowerCase().contains(q);
    }).toList();
  }
  
  get dividerColor => null;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color backgroundColor = isDarkMode ? Colors.grey[900]! : const Color(0xFFF9FAFB);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Organization Chart',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        automaticallyImplyLeading: false,
        leading: Container(
          margin: const EdgeInsets.all(8),
          child: FloatingActionButton(
            onPressed: () => Navigator.of(context).pop(),
            backgroundColor: _accentColor,
            mini: true,
            elevation: 2,
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode 
            ? null 
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [backgroundColor, Colors.white],
              ),
          color: isDarkMode ? scaffoldBackground : null,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with search and controls
              _buildHeaderSection(isDarkMode, textColor, hintColor, cardColor),

              // Filter chips
              _buildFilterChips(isDarkMode),

              const SizedBox(height: 8),

              // Content area
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 2.2,
                  boundaryMargin: const EdgeInsets.all(40),
                  child: SingleChildScrollView(
                    controller: _scrollCtr,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Leadership hierarchy
                        _buildLeadershipHierarchy(isDarkMode, textColor, cardColor, dividerColor),

                        const SizedBox(height: 24),

                        // Team area
                        _buildTeamSection(isDarkMode, textColor, cardColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Floating buttons
      floatingActionButton: _buildFloatingButtons(isDarkMode),
    );
  }

  Widget _buildHeaderSection(bool isDarkMode, Color textColor, Color hintColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Department Structure',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '${_teamMembers.length} members',
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: hintColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtr,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Search name or position...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: hintColor),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          onPressed: () => _searchCtr.clear(),
                          icon: Icon(Icons.clear, size: 20, color: hintColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  tooltip: 'Toggle view',
                  onPressed: () => setState(() => _compact = !_compact),
                  icon: Icon(
                    _compact ? Icons.view_agenda : Icons.grid_view,
                    color: hintColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    final filters = ['All', 'Manager', 'Executive', 'BPM', 'COTS', 'EMS', 'EPS'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color: _filter == filter ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                    fontSize: 13,
                  ),
                ),
                selected: _filter == filter,
                onSelected: (selected) => setState(() => _filter = selected ? filter : 'All'),
                selectedColor: _accentColor,
                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: _filter == filter ? _accentColor : (isDarkMode ? Colors.grey[600]! : Colors.grey.shade300),
                  width: 1,
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeadershipHierarchy(bool isDarkMode, Color textColor, Color cardColor, Color dividerColor) {
    final leaders = [
      {
        'name': 'Datuk Ir. Megat Jalaluddin Bin Megat Hassan',
        'role': 'President/Chief Executive Officer (CEO)'
      },
      {'name': 'Azlan Bin Ahmad', 'role': 'Chief Information Officer (CIO)'},
      {'name': 'Nik Sofizan Bin Nik Yusuf', 'role': 'Head of Delivery & Operation Services'},
      {'name': 'Azlul Shkib Arslan Bin Zaghlol', 'role': 'Chief Information Officer (CIO)'},
      {'name': 'Isfaruzi Bin Ismail', 'role': 'Lead Enterprise Solution (Non-SAP)'},
    ];

    return Column(
      children: List.generate(leaders.length, (index) {
        final leader = leaders[index];
        return Column(
          children: [
            _buildLeaderCard(leader['name']!, leader['role']!, isDarkMode, textColor, cardColor),
            if (index < leaders.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Icon(Icons.arrow_downward, size: 24, color: dividerColor),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildLeaderCard(String name, String role, bool isDarkMode, Color textColor, Color cardColor) {
    return GestureDetector(
      onTap: () => _showMemberDetails(context, name, role, isDarkMode, textColor, cardColor),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: _accentColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _accentColor, width: 2),
              ),
              child: Center(
                child: Text(
                  _getInitials(name),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: dividerColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection(bool isDarkMode, Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Team Members',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _compact ? _buildCompactList(isDarkMode, textColor, cardColor) : _buildGridList(isDarkMode, textColor, cardColor),
        ),
      ],
    );
  }

  Widget _buildGridList(bool isDarkMode, Color textColor, Color cardColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _filteredTeam.length,
      itemBuilder: (context, index) {
        final member = _filteredTeam[index];
        return _buildTeamMemberCard(member['name']!, member['role']!, isDarkMode, textColor, cardColor);
      },
    );
  }

  Widget _buildCompactList(bool isDarkMode, Color textColor, Color cardColor) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTeam.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 72,
        endIndent: 16,
        color: isDarkMode ? Colors.grey[700] : Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        final member = _filteredTeam[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(member['name']!),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
            ),
          ),
          title: Text(
            member['name']!,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          subtitle: Text(
            member['role']!,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          trailing: Icon(Icons.more_vert, color: isDarkMode ? Colors.grey[400] : Colors.black45, size: 20),
          onTap: () => _showMemberDetails(context, member['name']!, member['role']!, isDarkMode, textColor, cardColor),
        );
      },
    );
  }

  Widget _buildTeamMemberCard(String name, String role, bool isDarkMode, Color textColor, Color cardColor) {
    return GestureDetector(
      onTap: () => _showMemberDetails(context, name, role, isDarkMode, textColor, cardColor),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(name),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              role,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons(bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showScrollTop)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton(
              onPressed: () => _scrollCtr.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              ),
              mini: true,
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
              child: Icon(
                Icons.arrow_upward,
                color: _accentColor,
              ),
            ),
          ),
        FloatingActionButton(
          onPressed: () => _showLegend(context, isDarkMode),
          backgroundColor: _accentColor,
          child: const Icon(Icons.info_outline, color: Colors.white),
        ),
      ],
    );
  }

  void _showLegend(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final Color textColor = Theme.of(context).colorScheme.onBackground;
        final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
        
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization Chart Guide',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildLegendItem('Leadership Hierarchy', 'Shows the top management structure', isDarkMode, textColor, hintColor),
              _buildLegendItem('Team Members', 'All department members organized by roles', isDarkMode, textColor, hintColor),
              _buildLegendItem('Search & Filter', 'Find specific people or roles quickly', isDarkMode, textColor, hintColor),
              _buildLegendItem('View Toggle', 'Switch between grid and list views', isDarkMode, textColor, hintColor),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String title, String description, bool isDarkMode, Color textColor, Color hintColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: _accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberDetails(BuildContext context, String name, String role, bool isDarkMode, Color textColor, Color cardColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
        
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _accentColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(name),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  role,
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.email, 'Email', () {}),
                  _buildActionButton(Icons.chat, 'Message', () {}),
                  _buildActionButton(Icons.call, 'Call', () {}),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: _accentColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    } else if (parts.isNotEmpty) {
      return parts[0][0];
    }
    return '';
  }
}

// Sample team data
final List<Map<String, String>> _teamMembers = [
  {'name': 'Mohammad Azrulnizam Bin Kamaludin', 'role': 'Manager (Enterprise Mobility Solution)'},
  {'name': 'Mazran Noor Bin Mohamad Zain', 'role': 'Manager (Enterprise Portal Solution)'},
  {'name': 'Teng Jun Siong', 'role': 'Executive (EMS)'},
  {'name': 'Nurasmidar Binti Suaib', 'role': 'Executive (EPS)'},
  {'name': 'Sugunna Ambihai A/P Balachantar', 'role': 'Executive (EMS)'},
  {'name': 'Wan Nashrul Syafiq Bin Wan Roshdee', 'role': 'Executive (EPS)'},
  {'name': 'Adibah Binti Khaled', 'role': 'Manager (Enterprise Content Management)'},
  {'name': 'Noor Haffizah Binti Abu', 'role': 'Manager (Business Process Management)'},
  {'name': 'Nurelahajaraha Binti Mahamed Ramly', 'role': 'Manager (Commercial off-the-shelf)'},
  {'name': 'Nurul Aimi Athirah Binti Juarimi', 'role': 'Executive (BPM)'},
  {'name': 'Muhammad Hasif Bin Salim', 'role': 'Executive (COTS)'},
  {'name': 'Muhammad Hisham Bin Ahmad Asri', 'role': 'Executive (BPM)'},
  {'name': "Nur'Ainin Binti Md Jani", 'role': 'Executive (COTS)'}
];