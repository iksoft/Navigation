import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewPage extends StatelessWidget {
  final String url;

  WebViewPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Directions'),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
      ),
    );
  }
}
