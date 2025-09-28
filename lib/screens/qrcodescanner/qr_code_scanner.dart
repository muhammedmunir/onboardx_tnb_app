// lib/screens/scan_qr_screen.dart
import 'package:flutter/material.dart';

// alias mobile_scanner sebagai ms untuk elakkan konflik nama Phone/Email dll
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// alias flutter_contacts sebagai fc
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  final ms.MobileScannerController cameraController = ms.MobileScannerController();
  bool _scanning = true;
  bool _loading = false;
  bool _cameraPermissionGranted = false;

  late final TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _currentUserData;

  // NEW: toggle sama ada QR mengandungi vCard (boleh di-scan oleh kamera biasa)
  bool _qrAsVCard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkCameraPermission();
    _fetchCurrentUserData();
  }

  @override
  void dispose() {
    cameraController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
    } else {
      final result = await Permission.camera.request();
      setState(() => _cameraPermissionGranted = result.isGranted);
    }
  }

  Future<void> _fetchCurrentUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() => _currentUserData = Map<String, dynamic>.from(doc.data()!));
      } else {
        setState(() => _currentUserData = {});
      }
    }
  }

  void _handleBarcode(ms.BarcodeCapture capture) {
    if (!_scanning) return;

    final rawList = capture.barcodes;
    if (rawList.isEmpty) return;

    final String? scannedUid = rawList.first.rawValue;
    if (scannedUid == null || scannedUid.isEmpty) return;

    // NOTE: if you encode vCard in QR, the captured rawValue will be the full vCard text.
    // In that case your app logic must detect whether it's a UID or a vCard. Here we assume app QR for scanning app-to-app contains UID.
    // If you expect vCard scans from external apps, you probably won't handle them here.

    if (scannedUid == _auth.currentUser?.uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can't scan your own QR code")),
        );
      }
      return;
    }

    setState(() {
      _scanning = false;
      _loading = true;
    });

    // stop camera to avoid multiple detections
    cameraController.stop();
    _processScannedUid(scannedUid);
  }

  Future<void> _processScannedUid(String scannedUid) async {
    try {
      final doc = await _firestore.collection('users').doc(scannedUid).get();

      if (doc.exists) {
        final userData = Map<String, dynamic>.from(doc.data()!);
        userData['uid'] = scannedUid; // pastikan ada uid
        _showUserContactDialog(userData);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
        _resetScanner();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      _resetScanner();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUserContactDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('User Found'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userData['profileImageUrl'] != null &&
                  (userData['profileImageUrl'] as String).isNotEmpty)
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(userData['profileImageUrl']),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Name: ${userData['fullName'] ?? 'N/A'}'),
              Text('Username: ${userData['username'] ?? 'N/A'}'),
              Text('Email: ${userData['email'] ?? 'N/A'}'),
              Text('Phone: ${userData['phoneNumber'] ?? 'N/A'}'),
              Text('Work: ${userData['workType'] ?? 'N/A'}'),
              Text('Unit: ${userData['workUnit'] ?? 'N/A'}'),
              Text('Workplace: ${userData['workplace'] ?? 'N/A'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: const Text('Close'),
          ),
          // Keep only Save to Phone (no Save to App)
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveContactToPhone(userData);
            },
            child: const Text('Save to Phone'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveContactToPhone(Map<String, dynamic> userData) async {
    try {
      final hasPermission = await fc.FlutterContacts.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact permission is required')),
          );
        }
        _resetScanner();
        return;
      }

      final fullName = (userData['fullName'] ?? '').toString().trim();
      final parts = fullName.isNotEmpty ? fullName.split(' ') : <String>[];
      final givenName = parts.isNotEmpty ? parts.first : '';
      final familyName = (parts.length > 1) ? parts.sublist(1).join(' ') : '';

      final phoneValue = (userData['phoneNumber'] ?? '').toString();
      final emailValue = (userData['email'] ?? '').toString();
      final workplace = (userData['workplace'] ?? '').toString();
      final workInfo = (userData['workType'] ?? '').toString();

      // Bina contact menggunakan flutter_contacts API (fc)
      final fc.Contact newContact = fc.Contact(
        name: fc.Name(first: givenName, last: familyName),
        phones: phoneValue.isNotEmpty ? [fc.Phone(phoneValue)] : <fc.Phone>[],
        emails: emailValue.isNotEmpty ? [fc.Email(emailValue)] : <fc.Email>[],
        organizations: (workplace.isNotEmpty || workInfo.isNotEmpty)
            ? [fc.Organization(company: workplace, title: workInfo)]
            : <fc.Organization>[],
        notes: (workplace.isNotEmpty || workInfo.isNotEmpty)
            ? [fc.Note('${workplace}${workInfo.isNotEmpty ? ' • $workInfo' : ''}')]
            : <fc.Note>[],
      );

      // Masukkan contact ke device
      await newContact.insert();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved to phone successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving contact: $e')),
        );
      }
    } finally {
      _resetScanner();
    }
  }

  // NOTE: Save to Firestore removed (you wanted this deleted)

  void _resetScanner() {
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _loading = false;
    });
    // Start camera again (tidak menunggu hasil)
    cameraController.start();
  }

  Widget _buildScannerTab() {
    if (!_cameraPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64),
            const SizedBox(height: 16),
            const Text('Camera permission required'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkCameraPermission,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // gunakan alias ms.MobileScanner
        ms.MobileScanner(
          controller: cameraController,
          onDetect: _handleBarcode,
          fit: BoxFit.cover,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_loading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Text(
            'Scan a user QR code',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // Build vCard string from userData for external camera import
  String _buildVCard(Map<String, dynamic> userData) {
    // Minimal vCard 3.0
    final fullName = (userData['fullName'] ?? '').toString();
    final parts = fullName.split(' ');
    final family = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final given = parts.isNotEmpty ? parts.first : '';
    final tel = (userData['phoneNumber'] ?? '').toString();
    final email = (userData['email'] ?? '').toString();
    final org = (userData['workplace'] ?? '').toString();
    final title = (userData['workType'] ?? '').toString();

    // Escape newline/semicolons/commas if needed (basic)
    String escape(String s) => s.replaceAll('\n', '\\n').replaceAll(';', '\\;').replaceAll(',', '\\,');

    final buffer = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('N:${escape(family)};${escape(given)};;;')
      ..writeln('FN:${escape(fullName)}');
    if (tel.isNotEmpty) buffer.writeln('TEL;TYPE=CELL:${escape(tel)}');
    if (email.isNotEmpty) buffer.writeln('EMAIL;TYPE=INTERNET:${escape(email)}');
    if (org.isNotEmpty) buffer.writeln('ORG:${escape(org)}');
    if (title.isNotEmpty) buffer.writeln('TITLE:${escape(title)}');
    buffer.writeln('END:VCARD');

    return buffer.toString();
  }

  Widget _buildMyQrTab() {
    if (_currentUserData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String uid = _auth.currentUser?.uid ?? '';

    // Choose QR data: vCard or uid
    final qrData = _qrAsVCard ? _buildVCard(_currentUserData!) : uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_currentUserData!['profileImageUrl'] != null &&
                      (_currentUserData!['profileImageUrl'] as String).isNotEmpty)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          NetworkImage(_currentUserData!['profileImageUrl']),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUserData!['fullName'] ?? 'No Name',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '@${_currentUserData!['username'] ?? 'nousername'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _qrAsVCard
                        ? 'This QR contains a vCard — phone cameras/Google Lens can offer "Add contact".'
                        : 'Scan this QR code (app) to add me as a contact in-app',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (uid.isNotEmpty && !_qrAsVCard)
                    Text(
                      'User ID: ${uid.substring(0, 8)}...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Toggle QR type
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Use vCard QR (phone cameras)'),
              const SizedBox(width: 8),
              Switch(
                value: _qrAsVCard,
                onChanged: (v) => setState(() => _qrAsVCard = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Type', _currentUserData!['workType']),
                  _buildInfoRow('Unit', _currentUserData!['workUnit']),
                  _buildInfoRow('Workplace', _currentUserData!['workplace']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value?.toString() ?? 'Not specified')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final appBarColor =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;

    final primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1)
        : const Color.fromRGBO(224, 124, 124, 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QR Code',
          style: TextStyle(color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: appBarColor,
        foregroundColor: textColor,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: hintColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.person), text: 'My QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScannerTab(),
          _buildMyQrTab(),
        ],
      ),
    );
  }
}