// lib/screens/user_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

// Sesuaikan path Supabase import jika anda perlukan operasi khas (contoh: untuk follow/send request)
// import '../supabase.dart';

/// UserDetailScreen
/// - Menerima `userData` sebagai Map<String, dynamic>
/// - `isVCard` menunjukkan data ini datang dari QR vCard (true) atau dari app (false)
///
/// Contoh `userData` yang dijangka (camelCase):
/// {
///   'uid': '...', // nullable
///   'fullName': 'Muhammed Munir',
///   'username': 'mmunir',
///   'email': 'email@example.com',
///   'phoneNumber': '+60123456789',
///   'workType': 'Engineer',
///   'workUnit': 'Team 1',
///   'workTeam': 'Team 1',
///   'workplace': 'HQ',
///   'profileImageUrl': 'https://...',
/// }

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isVCard;

  const UserDetailScreen({Key? key, required this.userData, this.isVCard = false}) : super(key: key);

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _savingContact = false;

  String get _fullName => (widget.userData['fullName'] ?? '').toString();
  String get _username => (widget.userData['username'] ?? '').toString();
  String get _email => (widget.userData['email'] ?? '').toString();
  String get _phone => (widget.userData['phoneNumber'] ?? '').toString();
  String get _workType => (widget.userData['workType'] ?? '').toString();
  String get _workUnit => (widget.userData['workUnit'] ?? widget.userData['workTeam'] ?? '').toString();
  String get _workplace => (widget.userData['workplace'] ?? '').toString();
  String? get _profileImageUrl => widget.userData['profileImageUrl'] as String?;

  // Helper: buka telefon
  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Could not launch phone dialer');
    }
  }

  // Helper: hantar email
  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Could not open mail client');
    }
  }

  // Helper: salin ke clipboard
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label copied to clipboard');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Simpan contact ke phone menggunakan flutter_contacts
  Future<void> _saveContactToPhone() async {
    if (_fullName.isEmpty && _phone.isEmpty && _email.isEmpty) {
      _showSnack('No contact data to save');
      return;
    }

    setState(() => _savingContact = true);

    try {
      final hasPermission = await fc.FlutterContacts.requestPermission();
      if (!hasPermission) {
        _showSnack('Contact permission is required');
        return;
      }

      final parts = _fullName.isNotEmpty ? _fullName.split(' ') : <String>[];
      final givenName = parts.isNotEmpty ? parts.first : '';
      final familyName = (parts.length > 1) ? parts.sublist(1).join(' ') : '';

      final fc.Contact contact = fc.Contact(
        name: fc.Name(first: givenName, last: familyName),
        phones: _phone.isNotEmpty ? [fc.Phone(_phone)] : <fc.Phone>[],
        emails: _email.isNotEmpty ? [fc.Email(_email)] : <fc.Email>[],
        organizations: (_workplace.isNotEmpty || _workType.isNotEmpty)
            ? [fc.Organization(company: _workplace, title: _workType)]
            : <fc.Organization>[],
        notes: (_workplace.isNotEmpty || _workType.isNotEmpty)
            ? [fc.Note('${_workplace}${_workType.isNotEmpty ? ' • $_workType' : ''}')]
            : <fc.Note>[],
      );

      await contact.insert();

      _showSnack('Contact saved to phone successfully');
    } catch (e) {
      _showSnack('Error saving contact: $e');
    } finally {
      if (mounted) setState(() => _savingContact = false);
    }
  }

  // Optional: open a route to view user in app if uid present
  void _openInAppProfile() {
    final uid = widget.userData['uid'];
    if (uid == null || uid.toString().isEmpty) {
      _showSnack('No in-app profile available');
      return;
    }

    // TODO: navigate to your in-app user profile route
    // Example:
    // Navigator.pushNamed(context, '/profile', arguments: {'uid': uid});

    _showSnack('Open in-app profile (implement navigation)');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVCard ? 'Contact (vCard)' : 'User Detail'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildActionsRow(),
            const SizedBox(height: 16),
            _buildExtraActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _profileAvatar(56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullName.isNotEmpty ? _fullName : 'No name',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _username.isNotEmpty ? '@$_username' : '',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  if (_workUnit.isNotEmpty || _workplace.isNotEmpty)
                    Text(
                      '${_workUnit.isNotEmpty ? _workUnit : ''}${_workUnit.isNotEmpty && _workplace.isNotEmpty ? ' • ' : ''}${_workplace.isNotEmpty ? _workplace : ''}',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileAvatar(double size) {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(_profileImageUrl!),
      );
    }

    // fallback: initials
    final initials = _fullName.isNotEmpty
        ? _fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase()
        : '';

    return CircleAvatar(
      radius: size / 2,
      child: Text(initials, style: TextStyle(fontSize: size / 3)),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(icon: Icons.phone, label: 'Phone', value: _phone, onTap: _phone.isNotEmpty ? () => _launchPhone(_phone) : null, onCopy: _phone.isNotEmpty ? () => _copyToClipboard(_phone, 'Phone') : null),
            const Divider(),
            _infoRow(icon: Icons.email, label: 'Email', value: _email, onTap: _email.isNotEmpty ? () => _launchEmail(_email) : null, onCopy: _email.isNotEmpty ? () => _copyToClipboard(_email, 'Email') : null),
            const Divider(),
            _infoRow(icon: Icons.work, label: 'Work', value: '${_workType.isNotEmpty ? '$_workType • ' : ''}${_workUnit.isNotEmpty ? _workUnit : ''}${_workplace.isNotEmpty ? ' @ $_workplace' : ''}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value, VoidCallback? onTap, VoidCallback? onCopy}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: value.isNotEmpty ? Text(value) : Text('Not specified'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open',
              onPressed: onTap,
            ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: _savingContact ? const Text('Saving...') : const Text('Save to Phone'),
            onPressed: _savingContact ? null : _saveContactToPhone,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy_all),
            label: const Text('Copy All'),
            onPressed: () {
              final text = _buildPlainText();
              _copyToClipboard(text, 'Contact');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExtraActions() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.userData['uid'] != null)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Open in App'),
                subtitle: const Text('View full profile inside the app'),
                onTap: _openInAppProfile,
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Contact'),
              subtitle: const Text('Share vCard text or simple info'),
              onTap: () async {
                final plain = _buildPlainText();
                // Use system share via method channel or share_plus package
                // For minimal example, copy to clipboard and ask user to paste
                await _copyToClipboard(plain, 'Contact');
                _showSnack('Contact copied. Use share to paste elsewhere.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('Name: ${_fullName.isNotEmpty ? _fullName : '-'}');
    if (_username.isNotEmpty) buffer.writeln('Username: @$_username');
    if (_phone.isNotEmpty) buffer.writeln('Phone: $_phone');
    if (_email.isNotEmpty) buffer.writeln('Email: $_email');
    if (_workType.isNotEmpty) buffer.writeln('Work: $_workType');
    if (_workUnit.isNotEmpty) buffer.writeln('Unit: $_workUnit');
    if (_workplace.isNotEmpty) buffer.writeln('Workplace: $_workplace');
    if (widget.userData['uid'] != null) buffer.writeln('User ID: ${widget.userData['uid']}');
    return buffer.toString();
  }
}
