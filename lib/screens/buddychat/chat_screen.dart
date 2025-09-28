// import 'package:flutter/material.dart';
// import '../../models/buddy_model.dart';
// import '../../models/message_model.dart';
// import '../../widgets/message_bubble.dart';
// import '../../widgets/quick_reply_button.dart';

// class ChatScreen extends StatefulWidget {
//   final Buddy buddy;
//   final String? initialMessage;

//   const ChatScreen({
//     Key? key,
//     required this.buddy,
//     this.initialMessage,
//   }) : super(key: key);

//   @override
//   _ChatScreenState createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final List<Message> _messages = [];
//   final ScrollController _scrollController = ScrollController();

//   final List<QuickReply> _quickReplies = [
//     QuickReply('How do I request time off?', 'HR'),
//     QuickReply('What is the WiFi password?', 'Technical'),
//     QuickReply('How to access company portal?', 'Technical'),
//     QuickReply('Benefits enrollment period?', 'HR'),
//     QuickReply('Emergency contact update?', 'HR'),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _addWelcomeMessage();
//     if (widget.initialMessage != null) {
//       _addUserMessage(widget.initialMessage!);
//     }
//   }

//   void _addWelcomeMessage() {
//     _messages.add(Message(
//       id: DateTime.now().toString(),
//       senderId: widget.buddy.id,
//       senderName: widget.buddy.name,
//       text: _getWelcomeMessage(),
//       timestamp: DateTime.now(),
//       isMe: false,
//     ));
//   }

//   String _getWelcomeMessage() {
//     if (widget.buddy.department == 'HR') {
//       return "Hi! I'm ${widget.buddy.name}, your HR buddy. I'm here to help with any questions about company policies, benefits, or workplace culture. How can I assist you today?";
//     } else {
//       return "Hello! I'm ${widget.buddy.name} from Technical Support. I can help you with software, hardware, or access issues. What seems to be the problem?";
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.blue[700],
//         foregroundColor: Colors.white,
//         title: Row(
//           children: [
//             CircleAvatar(
//               backgroundImage: NetworkImage(widget.buddy.imageUrl),
//               radius: 18,
//             ),
//             SizedBox(width: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(widget.buddy.name),
//                 Text(
//                   widget.buddy.isOnline ? 'Online' : 'Offline',
//                   style: TextStyle(fontSize: 12),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.phone),
//             onPressed: _makePhoneCall,
//           ),
//           IconButton(
//             icon: Icon(Icons.more_vert),
//             onPressed: _showOptions,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Quick Replies Section
//           if (_messages.length <= 2)
//             Container(
//               height: 80,
//               padding: EdgeInsets.symmetric(vertical: 8),
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: _quickReplies.length,
//                 itemBuilder: (context, index) {
//                   final reply = _quickReplies[index];
//                   if (reply.category == widget.buddy.department || 
//                       reply.category == 'Both') {
//                     return QuickReplyButton(
//                       text: reply.text,
//                       onTap: () => _sendQuickReply(reply.text),
//                     );
//                   }
//                   return SizedBox.shrink();
//                 },
//               ),
//             ),

//           // Messages List
//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: EdgeInsets.all(16),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final message = _messages[index];
//                 return MessageBubble(message: message);
//               },
//             ),
//           ),

//           // Input Section
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   offset: Offset(0, -2),
//                   blurRadius: 4,
//                   color: Colors.black12,
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 // Attachment Button
//                 IconButton(
//                   icon: Icon(Icons.attach_file),
//                   onPressed: _attachFile,
//                 ),
                
//                 // Message Input
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Type a message...',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                       ),
//                       contentPadding: EdgeInsets.symmetric(horizontal: 16),
//                     ),
//                     onSubmitted: (text) => _sendMessage(),
//                   ),
//                 ),
                
//                 // Send Button
//                 IconButton(
//                   icon: Icon(Icons.send),
//                   color: Colors.blue[700],
//                   onPressed: _sendMessage,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _sendMessage() {
//     final text = _messageController.text.trim();
//     if (text.isNotEmpty) {
//       setState(() {
//         _messages.add(Message(
//           id: DateTime.now().toString(),
//           senderId: 'user',
//           senderName: 'You',
//           text: text,
//           timestamp: DateTime.now(),
//           isMe: true,
//         ));
//         _messageController.clear();
//       });
//       _scrollToBottom();
      
//       // Simulate buddy reply after 1-3 seconds
//       Future.delayed(Duration(seconds: 1 + (DateTime.now().millisecond % 3)), () {
//         _addBuddyReply(text);
//       });
//     }
//   }

//   void _sendQuickReply(String text) {
//     setState(() {
//       _messages.add(Message(
//         id: DateTime.now().toString(),
//         senderId: 'user',
//         senderName: 'You',
//         text: text,
//         timestamp: DateTime.now(),
//         isMe: true,
//       ));
//     });
//     _scrollToBottom();
    
//     Future.delayed(Duration(seconds: 1), () {
//       _addBuddyReply(text);
//     });
//   }

//   void _addUserMessage(String text) {
//     setState(() {
//       _messages.add(Message(
//         id: DateTime.now().toString(),
//         senderId: 'user',
//         senderName: 'You',
//         text: text,
//         timestamp: DateTime.now(),
//         isMe: true,
//       ));
//     });
//     _scrollToBottom();
//   }

//   void _addBuddyReply(String userMessage) {
//     setState(() {
//       _messages.add(Message(
//         id: DateTime.now().toString(),
//         senderId: widget.buddy.id,
//         senderName: widget.buddy.name,
//         text: _generateReply(userMessage),
//         timestamp: DateTime.now(),
//         isMe: false,
//       ));
//     });
//     _scrollToBottom();
//   }

//   String _generateReply(String userMessage) {
//     // Simple AI-like response generation
//     if (userMessage.toLowerCase().contains('password') || 
//         userMessage.toLowerCase().contains('wifi')) {
//       return "The WiFi password is 'Company2024!'. You can find this information in your onboarding package as well.";
//     } else if (userMessage.toLowerCase().contains('time off') || 
//                userMessage.toLowerCase().contains('leave')) {
//       return "You can request time off through our HR portal. Go to Portal > Time Off > New Request. Need help accessing the portal?";
//     } else if (userMessage.toLowerCase().contains('benefit')) {
//       return "Benefits enrollment is open for the first 30 days of employment. I can send you the benefits guide. Would you like me to do that?";
//     } else {
//       return "Thanks for your question. Let me check that for you. In the meantime, is there anything else I can help with?";
//     }
//   }

//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   void _makePhoneCall() {
//     // Implement phone call functionality
//   }

//   void _attachFile() {
//     // Implement file attachment functionality
//   }

//   void _showOptions() {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: Icon(Icons.history),
//                 title: Text('Chat History'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   // Navigate to chat history
//                 },
//               ),
//               ListTile(
//                 leading: Icon(Icons.help),
//                 title: Text('FAQ'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   // Navigate to FAQ
//                 },
//               ),
//               ListTile(
//                 leading: Icon(Icons.report),
//                 title: Text('Report Issue'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   // Report issue functionality
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class QuickReply {
//   final String text;
//   final String category;

//   QuickReply(this.text, this.category);
// }