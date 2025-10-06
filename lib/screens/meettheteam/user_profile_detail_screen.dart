import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfileDetailScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserProfileDetailScreen({super.key, required this.userData});

  // Function to launch email
  _launchEmail(String email) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    } else {
      throw 'Could not launch email';
    }
  }

  // Function to launch phone call
  _launchPhone(String phone) async {
    final Uri params = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    } else {
      throw 'Could not launch phone';
    }
  }

  // Function to launch WhatsApp
  _launchWhatsApp(String phone) async {
    // Remove any non-digit characters except +
    String cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    final Uri params = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanedPhone,
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    final String fullName = userData['fullName'] ?? 'N/A';
    final String position = userData['workType'] ?? 'N/A';
    final String email = userData['email'] ?? 'N/A';
    final String phone = userData['phoneNumber'] ?? 'N/A';
    final String? profileImageUrl = userData['profileImageUrl'];

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'User Profile Detail',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty) ? NetworkImage(profileImageUrl) : null,
                child: (profileImageUrl == null || profileImageUrl.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            
            // Name Section
            _buildProfileSection(
              title: 'Name',
              content: fullName,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            
            // Position Section
            _buildProfileSection(
              title: 'Position',
              content: position,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            
            // Email Section
            _buildEmailSection(
              title: 'Email',
              content: email,
              isDarkMode: isDarkMode,
              textColor: textColor,
              dividerColor: dividerColor,
            ),
            
            // Phone Section
            _buildPhoneSection(
              title: 'Phone',
              content: phone,
              isDarkMode: isDarkMode,
              textColor: textColor,
              dividerColor: dividerColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required String content,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(224, 124, 124, 1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 16,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        Divider(
          thickness: 1,
          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmailSection({
    required String title,
    required String content,
    required bool isDarkMode,
    required Color textColor,
    required Color dividerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(224, 124, 124, 1),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _launchEmail(content),
          child: Row(
            children: [
              Icon(Icons.email, color: isDarkMode ? Colors.grey[400] : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(
          thickness: 1,
          color: dividerColor,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPhoneSection({
    required String title,
    required String content,
    required bool isDarkMode,
    required Color textColor,
    required Color dividerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(224, 124, 124, 1),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.phone, color: isDarkMode ? Colors.grey[400] : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // WhatsApp button
            InkWell(
              onTap: () => _launchWhatsApp(content),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.message,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Phone call button
            InkWell(
              onTap: () => _launchPhone(content),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.call,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(
          thickness: 1,
          color: dividerColor,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}