import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';

/// Reproduz o link do exercício dentro do app (WebView). YouTube e Vimeo viram embed.
class ExerciseVideoWebPage extends StatefulWidget {
  const ExerciseVideoWebPage({
    super.key,
    required this.initialUrl,
    this.title = 'Vídeo',
  });

  final String initialUrl;
  final String title;

  /// Ajusta URLs conhecidas para player embutido; demais https mantém o endereço original.
  static Uri? normalizeVideoUri(String raw) {
    final t = raw.trim();
    final uri = Uri.tryParse(t);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);

    if (host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) {
        return Uri.parse('https://www.youtube.com/embed/$v?playsinline=1');
      }
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
        return uri;
      }
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
        final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        if (id != null && id.isNotEmpty) {
          return Uri.parse('https://www.youtube.com/embed/$id?playsinline=1');
        }
      }
    }
    if (host == 'youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (id != null && id.isNotEmpty) {
        return Uri.parse('https://www.youtube.com/embed/$id?playsinline=1');
      }
    }

    if (host.contains('vimeo.com')) {
      final segs = uri.pathSegments;
      for (final s in segs) {
        if (RegExp(r'^\d+$').hasMatch(s)) {
          return Uri.parse('https://player.vimeo.com/video/$s');
        }
      }
    }

    return uri;
  }

  @override
  State<ExerciseVideoWebPage> createState() => _ExerciseVideoWebPageState();
}

class _ExerciseVideoWebPageState extends State<ExerciseVideoWebPage> {
  WebViewController? _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final target = ExerciseVideoWebPage.normalizeVideoUri(widget.initialUrl);
    if (target == null) {
      _error = 'Endereço de vídeo inválido.';
      _loading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            setState(() {
              _loading = false;
              _error = err.description.isNotEmpty ? err.description : 'Erro ao carregar a página.';
            });
          },
        ),
      )
      ..loadRequest(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              ),
            )
          else if (_controller != null)
            WebViewWidget(controller: _controller!),
          if (_loading && _error == null && _controller != null)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.splashMint,
                backgroundColor: AppColors.barBackground,
              ),
            ),
        ],
      ),
    );
  }
}
