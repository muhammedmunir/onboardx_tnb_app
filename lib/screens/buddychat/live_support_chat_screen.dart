import 'package:flutter/material.dart';

class LiveSupportChatScreen extends StatelessWidget {
  final String supportType;

  const LiveSupportChatScreen({super.key, required this.supportType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sokongan $supportType'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Mesej alu-aluan automatik
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Anda sedang berhubung dengan ejen sokongan. Seorang ejen akan membalas sebentar lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Perbualan dengan $supportType akan dipaparkan di sini.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }
  
  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      color: Colors.white,
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration.collapsed(
                hintText: 'Huraikan masalah anda...',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blue.shade700),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}