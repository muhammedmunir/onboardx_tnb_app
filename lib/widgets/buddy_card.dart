import 'package:flutter/material.dart';
import '../models/buddy_model.dart';

class BuddyCard extends StatelessWidget {
  final Buddy buddy;
  final VoidCallback onTap;

  const BuddyCard({
    Key? key,
    required this.buddy,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(buddy.imageUrl),
              radius: 24,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: buddy.isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          buddy.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(buddy.role),
            Text(
              buddy.department,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Wrap(
              spacing: 4,
              children: buddy.specialties.take(3).map((specialty) {
                return Chip(
                  label: Text(specialty),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
        trailing: Icon(Icons.chat_bubble_outline),
        onTap: onTap,
      ),
    );
  }
}