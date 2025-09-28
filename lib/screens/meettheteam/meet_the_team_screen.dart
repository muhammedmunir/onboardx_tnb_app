import 'package:flutter/material.dart';
import 'package:onboardx_tnb_app/screens/meettheteam/organization_chart_screen.dart';
import 'package:onboardx_tnb_app/screens/meettheteam/user_profile_detail_screen.dart';

class MeetTheTeamScreen extends StatefulWidget {
  const MeetTheTeamScreen({super.key});

  @override
  State<MeetTheTeamScreen> createState() => _MeetTheTeamScreenState();
}

class _MeetTheTeamScreenState extends State<MeetTheTeamScreen> {
  final List<TeamMember> teamMembers = [
    TeamMember(
      name: "Datu k. l. Megat Jalaluddin Bin Megat Hassan",
      position: "President/Actual Pegawati Executual (CEO)",
    ),
    TeamMember(
      name: "Azlan Bin Ahmad",
      position: "Chief Information Officer (CIO)",
    ),
    TeamMember(
      name: "Nik Sofizan Bin Nik Yusuf",
      position: "Head (Center of Delivery & Operation Services)",
    ),
    TeamMember(
      name: "Azlul Shkib Arslan Bin Zaghlol",
      position: "Head (Corporate & Engineering Services)",
    ),
    TeamMember(
      name: "Isfaruzi Bin Ismail",
      position: "Lead (Enterprise Solution [Non-SAPI])",
    ),
    TeamMember(
      name: "Mohammad Azruinizam Bin Kamaludin",
      position: "Manager (Enterprise Mobility Solution)",
    ),
    TeamMember(
      name: "Mazran Noor Bin Mohamad Zain",
      position: "Manager (Enterprise Portal Solution)",
    ),
    TeamMember(
      name: "Adiban Binti Khaled",
      position: "Manager (Enterprise Content Management)",
    ),
    TeamMember(
      name: "Noor Haffizah Binti Abu",
      position: "Manager (Business Process Management)",
    ),
    TeamMember(
      name: "Nurelahajaraha Binti Mahamed Ramly",
      position: "Manager (Commercial off-the-shelf)",
    ),
    TeamMember(
      name: "Muhammad Hasif Bin Salim",
      position: "Executive (COTS)",
    ),
    TeamMember(
      name: "NurAlnin Binti Md Jani",
      position: "Executive (COTS)",
    ),
    TeamMember(
      name: "Nurasmidar Binti Sualb",
      position: "Executive (EPS)",
    ),
    TeamMember(
      name: "Nurul Aimi Athirah Binti Juarimi",
      position: "Executive (BPM)",
    ),
    TeamMember(
      name: "Muhammad Hisham Bin Ahmad Asri",
      position: "Executive (BPM)",
    ),
    TeamMember(
      name: "Wan Nashrul Syafiq Bin Wan Roshdee",
      position: "Executive (EPS)",
    ),
    TeamMember(
      name: "Teng Jun Siong",
      position: "Executive (EMS)",
    ),
    TeamMember(
      name: "Sugunna Ambihai A/P Balachantar",
      position: "Executive (EMS)",
    ),
  ];

  List<TeamMember> filteredMembers = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredMembers = teamMembers;
    searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterMembers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredMembers = teamMembers;
      } else {
        filteredMembers = teamMembers.where((member) {
          return member.name.toLowerCase().contains(query) ||
              member.position.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color cardColor = Theme.of(context).cardColor;
    final Color searchFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Meet The Team',
          style: TextStyle(color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        automaticallyImplyLeading: false,
        leading: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(224, 124, 124, 1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Department Directory Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Department Directory',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrganizationChartScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(224, 124, 124, 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.business,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search Now...',
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                filled: true,
                fillColor: searchFillColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              style: TextStyle(color: textColor),
            ),
          ),

          // Team Members List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16.0),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                return TeamMemberCard(member: member, isDarkMode: isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TeamMember {
  final String name;
  final String position;

  TeamMember({required this.name, required this.position});
}

class TeamMemberCard extends StatelessWidget {
  final TeamMember member;
  final bool isDarkMode;

  const TeamMemberCard({super.key, required this.member, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: isDarkMode ? 0 : 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: isDarkMode 
          ? BorderSide(color: Colors.grey[700]!, width: 1) 
          : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserProfileDetailScreen(
                //member: member, // hantar data kalau perlu
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                member.position,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}