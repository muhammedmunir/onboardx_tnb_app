import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
void initState() {
  super.initState();

  _webViewController = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          setState(() {
            _progress = progress / 100;
            _isLoading = progress < 100;
          });
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
          print('Page finished loading: $url');
        },
        onWebResourceError: (WebResourceError error) async {
          setState(() {
            _isLoading = false;
          });
          print('WebView error: ${error.errorCode} - ${error.description}');

          // If WebView can't render (commonly for PDF on Android), try opening externally
          final uri = Uri.tryParse(widget.documentUrl);
          if (uri != null) {
            try {
              // Use url_launcher to open externally
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              print('Failed to launch externally: $e');
            }
          }
        },
        onUrlChange: (UrlChange change) {
          print('URL changed to: ${change.url}');
        },
      ),
    )
    ..loadRequest(Uri.parse(widget.documentUrl));
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentTitle),
        backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color.fromRGBO(224, 124, 124, 1),
              ),
            ),
        ],
      ),
    );
  }
}