import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String documentUrl;
  final String documentTitle;
  final String contentType;

  const DocumentViewerScreen({
    super.key,
    required this.documentUrl,
    required this.documentTitle,
    required this.contentType,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isPdf = false;
  bool _isLoading = true;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _checkFileType();
  }

  void _checkFileType() {
    final url = widget.documentUrl.toLowerCase();
    _isPdf = url.endsWith('.pdf') || widget.contentType.toLowerCase().contains('pdf');
    
    if (_isPdf) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              print('WebView loading: $progress%');
            },
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              print('WebView error: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.documentUrl));
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _openExternally() async {
    try {
      final uri = Uri.parse(widget.documentUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the document')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentTitle),
        actions: [
          if (_isPdf)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _openExternally,
              tooltip: 'Open in external app',
            ),
        ],
      ),
      body: _isLoading && _isPdf
          ? const Center(child: CircularProgressIndicator())
          : _isPdf
              ? WebViewWidget(controller: _webViewController)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Document Type: ${widget.contentType}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openExternally,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}