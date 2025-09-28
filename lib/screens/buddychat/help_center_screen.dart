import 'package:flutter/material.dart';
import 'live_support_chat_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pusat Bantuan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Bahagian 1: Buddy Section
          _buildBuddyCard(context),
          const SizedBox(height: 24),

          // Bahagian 2: Live Support
          _buildLiveSupportSection(context),
          const SizedBox(height: 24),
          
          // Bahagian 3: Self-Service
          _buildSelfServiceSection(context),
        ],
      ),
      // Floating Action Button untuk Chatbot
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Logik untuk membuka chatbot (contoh: showModalBottomSheet)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chatbot dibuka!')),
          );
        },
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.smart_toy),
        tooltip: 'Chat dengan Bot Bantuan',
      ),
    );
  }

  // Widget untuk kad Buddy
  Widget _buildBuddyCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  // Ganti dengan gambar sebenar
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'), 
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ahmad Faizal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Senior Developer',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Status online indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Online', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat dengan Buddy Anda'),
                onPressed: () {
                  Navigator.pushNamed(context, '/buddy_chat');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk bahagian Live Support
  Widget _buildLiveSupportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sokongan Langsung',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              _buildSupportTile(
                context,
                icon: Icons.computer,
                title: 'Sokongan Teknikal (IT)',
                subtitle: 'Masalah laptop, perisian, atau akses sistem.',
                supportType: 'Teknikal',
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSupportTile(
                context,
                icon: Icons.people_outline,
                title: 'Jabatan Sumber Manusia (HR)',
                subtitle: 'Soalan mengenai gaji, cuti, atau polisi.',
                supportType: 'HR',
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Widget untuk bahagian Self-Service
  Widget _buildSelfServiceSection(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text(
            'Bantuan Kendiri',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                    leading: const Icon(Icons.quiz_outlined, color: Colors.blue),
                    title: const Text('Soalan Lazim (FAQ)'),
                    subtitle: const Text('Cari jawapan untuk soalan-soalan umum.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                        Navigator.pushNamed(context, '/faq');
                    },
                ),
            ),
        ],
    );
  }

  // Helper untuk membina setiap baris pilihan sokongan
  ListTile _buildSupportTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required String supportType}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveSupportChatScreen(supportType: supportType),
          ),
        );
      },
    );
  }
}