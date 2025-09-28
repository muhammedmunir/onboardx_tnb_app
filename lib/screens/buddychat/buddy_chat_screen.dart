import 'package:flutter/material.dart';

class BuddyChatScreen extends StatelessWidget {
  const BuddyChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'),
            ),
            SizedBox(width: 12),
            Text('Ahmad Faizal'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Bahagian ini akan memaparkan senarai mesej
          Expanded(
            child: Center(
              child: Text(
                'Mesej anda akan dipaparkan di sini.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
          // Bahagian untuk taip mesej
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.blue.shade700),
            onPressed: () {},
          ),
          const Expanded(
            child: TextField(
              decoration: InputDecoration.collapsed(
                hintText: 'Taip mesej...',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blue.shade700),
            onPressed: () {
              // Hantar mesej
            },
          ),
        ],
      ),
    );
  }
}