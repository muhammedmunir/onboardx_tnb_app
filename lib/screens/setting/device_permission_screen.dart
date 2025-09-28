import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class DevicePermissionScreen extends StatefulWidget {
  const DevicePermissionScreen({super.key});

  @override
  State<DevicePermissionScreen> createState() => _DevicePermissionScreenState();
}

class _DevicePermissionScreenState extends State<DevicePermissionScreen> {
  // Map to track permission statuses
  Map<Permission, PermissionStatus> permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    // Initialize and check all permission statuses
    _checkAllPermissions();
  }

  // Check status of all relevant permissions
  Future<void> _checkAllPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.location,
      Permission.storage,
      Permission.microphone,
      Permission.contacts,
      Permission.notification,
      Permission.photos,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    
    for (var permission in permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      permissionStatuses = statuses;
    });
  }

  // Request a specific permission
  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    
    setState(() {
      permissionStatuses[permission] = status;
    });
    
    // Show a snackbar with the result
    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_getPermissionName(permission)} permission granted')),
      );
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_getPermissionName(permission)} permission denied')),
      );
    } else if (status.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedDialog(permission);
    }
  }

  // Show dialog when permission is permanently denied
  void _showPermissionPermanentlyDeniedDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            '${_getPermissionName(permission)} permission is permanently denied. '
            'Please enable it in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // Get user-friendly name for each permission
  String _getPermissionName(Permission permission) {
    if (permission == Permission.camera) return 'Camera';
    if (permission == Permission.location) return 'Location';
    if (permission == Permission.storage) return 'Storage';
    if (permission == Permission.microphone) return 'Microphone';
    if (permission == Permission.contacts) return 'Contacts';
    if (permission == Permission.notification) return 'Notifications';
    if (permission == Permission.photos) return 'Photos';
    return 'Unknown';
  }

  // Get icon for each permission
  IconData _getPermissionIcon(Permission permission) {
    if (permission == Permission.camera) return Icons.camera_alt_outlined;
    if (permission == Permission.location) return Icons.location_on_outlined;
    if (permission == Permission.storage) return Icons.storage_outlined;
    if (permission == Permission.microphone) return Icons.mic_outlined;
    if (permission == Permission.contacts) return Icons.contacts_outlined;
    if (permission == Permission.notification) return Icons.notifications_outlined;
    if (permission == Permission.photos) return Icons.photo_library_outlined;
    return Icons.question_mark_outlined;
  }

  // Get color based on permission status
  Color _getStatusColor(PermissionStatus status) {
    if (status.isGranted) return Colors.green;
    if (status.isDenied) return Colors.orange;
    if (status.isPermanentlyDenied) return Colors.red;
    if (status.isRestricted) return Colors.purple;
    return Colors.grey;
  }

  // Get text based on permission status
  String _getStatusText(PermissionStatus status) {
    if (status.isGranted) return 'Granted';
    if (status.isDenied) return 'Denied';
    if (status.isPermanentlyDenied) return 'Permanently Denied';
    if (status.isRestricted) return 'Restricted';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Permissions'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Manage App Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'These permissions help the app function properly. '
              'You can enable or disable them as needed.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: ListView(
              children: permissionStatuses.entries.map((entry) {
                final permission = entry.key;
                final status = entry.value;
                
                return _buildPermissionTile(
                  icon: _getPermissionIcon(permission),
                  title: _getPermissionName(permission),
                  status: status,
                  onTap: () => _requestPermission(permission),
                );
              }).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Note: Some features may not work correctly if permissions are denied.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 28),
      title: Text(title),
      subtitle: Text(
        _getStatusText(status),
        style: TextStyle(color: _getStatusColor(status)),
      ),
      trailing: IconButton(
        icon: Icon(
          status.isGranted ? Icons.check_circle : Icons.pending,
          color: _getStatusColor(status),
        ),
        onPressed: onTap,
      ),
      onTap: onTap,
    );
  }
}