import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/gradient_app_bar.dart';

/// Como o player é apresentado: tela cheia ou janela (dialog) dentro do app.
enum ExerciseVideoPresentation {
  /// `Navigator.push` com [Scaffold] + AppBar.
  fullScreen,

  /// Modal com bordas arredondadas sobre o conteúdo atual.
  dialog,
}

/// Reproduz o link do exercício dentro do app (WebView).
/// Para YouTube, preferimos URL "watch" (não "embed") para evitar erro 153 em alguns WebViews iOS.
class ExerciseVideoWebPage extends StatefulWidget {
  const ExerciseVideoWebPage({
    super.key,
    required this.initialUrl,
    this.title = 'Vídeo',
    this.presentation = ExerciseVideoPresentation.fullScreen,
  });

  final String initialUrl;
  final String title;
  final ExerciseVideoPresentation presentation;

  /// Abre o vídeo numa **janela modal** no próprio app (WebView embutido).
  static Future<void> showInAppWindow(
    BuildContext context, {
    required String initialUrl,
    String title = 'Vídeo',
  }) async {
    if (normalizeVideoUri(initialUrl) == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Endereço de vídeo inválido.')),
      );
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      enableDrag: true,
      showDragHandle: false,
      useSafeArea: true,
      isDismissible: true,
      builder: (sheetContext) {
        final size = MediaQuery.sizeOf(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: size.width - 20,
              height: size.height * 0.9,
              child: ExerciseVideoWebPage(
                initialUrl: initialUrl,
                title: title,
                presentation: ExerciseVideoPresentation.dialog,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Ajusta URLs conhecidas para formato compatível com WebView; demais https mantêm o endereço original.
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
        return Uri.https('www.youtube.com', '/watch', {'v': v});
      }
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
        final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        if (id != null && id.isNotEmpty) {
          return Uri.https('www.youtube.com', '/watch', {'v': id});
        }
      }
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shorts') {
        final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        if (id != null && id.isNotEmpty) {
          return Uri.https('www.youtube.com', '/watch', {'v': id});
        }
      }
    }
    if (host == 'youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (id != null && id.isNotEmpty) {
        return Uri.https('www.youtube.com', '/watch', {'v': id});
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

  Widget _buildBody() {
    return Stack(
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
    );
  }

  Widget _buildDialogChrome() {
    return Material(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.barBackground,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.presentation == ExerciseVideoPresentation.dialog) {
      return _buildDialogChrome();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildGradientAppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }
}
