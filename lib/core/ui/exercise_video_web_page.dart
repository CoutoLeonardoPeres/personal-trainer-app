import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
/// YouTube usa sempre a página **watch** (não `/embed/`): o embed costuma falhar no WebView
/// com **erro 153** (“Video unavailable”) em iOS/Android.
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

  static bool _isYouTubeUri(Uri uri) {
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    return host.contains('youtube.com') || host == 'youtu.be';
  }

  /// Abre YouTube no visualizador nativo (mais estável que WKWebView em alguns links).
  static Future<bool> _openYouTubeExternally(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Abre o vídeo num **popup suspenso** ao centro (~60% da altura da tela, WebView embutido).
  static Future<void> showInAppWindow(
    BuildContext context, {
    required String initialUrl,
    String title = 'Vídeo',
  }) async {
    final target = normalizeVideoUri(initialUrl);
    if (target == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Endereço de vídeo inválido.')),
      );
      return;
    }
    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        final panelW = (size.width * 0.92).clamp(280.0, 720.0);
        final panelH = size.height * 0.6;
        return SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: panelW,
                height: panelH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.black.withValues(alpha: 0.42),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.92),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19.5),
                  child: Material(
                    color: AppColors.background,
                    clipBehavior: Clip.antiAlias,
                    child: ExerciseVideoWebPage(
                      initialUrl: initialUrl,
                      title: title,
                      presentation: ExerciseVideoPresentation.dialog,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Ajusta URLs conhecidas para formato compatível com WebView; demais https mantêm o endereço original.
  static Uri? normalizeVideoUri(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
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
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    final target = ExerciseVideoWebPage.normalizeVideoUri(widget.initialUrl);
    if (target == null) {
      _error = 'Endereço de vídeo inválido.';
      _loading = false;
      return;
    }
    _initWebView(target);
  }

  void _initWebView(Uri target) {
    try {
      late final PlatformWebViewControllerCreationParams creationParams;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        creationParams = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
        );
      } else {
        creationParams = const PlatformWebViewControllerCreationParams();
      }

      final controller = WebViewController.fromPlatformCreationParams(
        creationParams,
      )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.background)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (!mounted || _disposed) return;
              setState(() {
                _loading = true;
                _error = null;
              });
            },
            onPageFinished: (_) {
              if (!mounted || _disposed) return;
              setState(() => _loading = false);
            },
            onWebResourceError: (err) {
              if (!mounted || _disposed) return;
              setState(() {
                _loading = false;
                _error = err.description.isNotEmpty
                    ? err.description
                    : 'Erro ao carregar a página.';
              });
            },
          ),
        );

      if (controller.platform is AndroidWebViewController) {
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      controller.loadRequest(target);
      _controller = controller;
    } catch (e) {
      _error = 'Não foi possível iniciar o player de vídeo.';
      _loading = false;
    }
  }

  Future<void> _openYouTubeFallback() async {
    final target = ExerciseVideoWebPage.normalizeVideoUri(widget.initialUrl);
    if (target == null) return;
    await ExerciseVideoWebPage._openYouTubeExternally(target);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Widget _buildBody() {
    final target = ExerciseVideoWebPage.normalizeVideoUri(widget.initialUrl);
    final showYoutubeFallback =
        target != null && ExerciseVideoWebPage._isYouTubeUri(target);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                    ),
                  ),
                  if (showYoutubeFallback) ...[
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _openYouTubeFallback,
                      child: const Text('Abrir no YouTube'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else if (_controller != null)
          ClipRect(
            child: WebViewWidget(controller: _controller!),
          ),
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
                padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Fechar',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.splashMint.withValues(alpha: 0.98),
                                  AppColors.accentGreen.withValues(alpha: 0.82),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                                width: 1.75,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.splashMint.withValues(
                                    alpha: 0.55,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF0A1620),
                              size: 26,
                              weight: 700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }
}
