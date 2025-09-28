// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import '../../models/buddy_model.dart';
// import '../../data/buddies_data.dart';
// import '../../widgets/buddy_card.dart';
// import 'chat_screen.dart';
// import 'pre_chat_form_screen.dart';

// class SupportHomeScreen extends StatelessWidget {
//   const SupportHomeScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Support System'),
//         backgroundColor: Colors.blue[700],
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header Section
//             const Text(
//               'How can we help you today?',
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 8),
//             const Text(
//               'Choose a support option below',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey,
//               ),
//             ),
//             const SizedBox(height: 32),

//             // Quick Support Cards
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildSupportCard(
//                     context,
//                     icon: Icons.computer,
//                     title: 'Technical Support',
//                     subtitle: 'Software, hardware, access issues',
//                     color: Colors.orange,
//                     onTap: () => _navigateToTechSupport(context),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: _buildSupportCard(
//                     context,
//                     icon: Icons.people,
//                     title: 'HR Buddy',
//                     subtitle: 'Policies, benefits, culture',
//                     color: Colors.green,
//                     onTap: () => _navigateToHRBuddy(context),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 32),

//             // Assigned Buddies Section
//             const Text(
//               'Your Support Buddies',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 16),

//             Expanded(
//               child: ListView.builder(
//                 itemCount: buddies.length,
//                 itemBuilder: (context, index) {
//                   return BuddyCard(
//                     buddy: buddies[index],
//                     onTap: () => _navigateToChat(context, buddies[index]),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSupportCard(
//     BuildContext context, {
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(icon, size: 30, color: color),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 subtitle,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _navigateToTechSupport(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => PreChatFormScreen(
//           supportType: 'Technical Support',
//           onStartChat: (issue) {
//             // Handle starting chat with tech support
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => ChatScreen(
//                   buddy: Buddy(
//                     id: 'tech_bot',
//                     name: 'Technical Support Bot',
//                     role: 'AI Assistant',
//                     department: 'IT',
//                     imageUrl: 'assets/tech_bot.png',
//                     isOnline: true,
//                     specialties: ['Software', 'Hardware', 'Access'],
//                     email: 'tech@company.com',
//                     phone: '',
//                   ),
//                   initialMessage: issue,
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   void _navigateToHRBuddy(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => PreChatFormScreen(
//           supportType: 'HR Support',
//           onStartChat: (issue) {
//             // Handle starting chat with HR
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => ChatScreen(
//                   buddy: buddies.firstWhere(
//                     (buddy) => buddy.department == 'HR',
//                     orElse: () => buddies[0],
//                   ),
//                   initialMessage: issue,
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   void _navigateToChat(BuildContext context, Buddy buddy) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ChatScreen(buddy: buddy),
//       ),
//     );
//   }
// }