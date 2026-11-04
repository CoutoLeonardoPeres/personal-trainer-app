import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Logs para Console/Xcode e DevTools (filtro: `app_personal`).
///
/// **iOS:** no Mac, abra o app **Console.app** → dispositivo → filtre por
/// `com.personaltrainer.app.Personal` (Swift) ou `app_personal` (Dart).
void logLaunch(
  String message, {
  String phase = 'dart',
  Object? error,
  StackTrace? stackTrace,
}) {
  final ts = DateTime.now().toIso8601String();
  final line = '[$ts][$phase] $message';
  debugPrint(line);
  developer.log(
    message,
    name: 'app_personal.$phase',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Registra erros não tratados (útil se o app “morre” ao voltar do ícone).
void installGlobalErrorLogging() {
  FlutterError.onError = (FlutterErrorDetails details) {
    logLaunch(
      details.exceptionAsString(),
      phase: 'flutter_error',
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logLaunch(
      '$error',
      phase: 'platform_error',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}

void logLifecycle(AppLifecycleState state) {
  logLaunch('AppLifecycleState.$state', phase: 'lifecycle');
}

// ——— Diagnóstico de arranque (tela preta / travamentos) ———

/// Passos do boot — no Mac: **Console.app** ou terminal do `flutter run`, filtre por **`[BOOT]`**
/// ou pelo nome `app_personal.boot`.
void bootTrace(String step, [Object? detail]) {
  final extra = detail != null ? ': $detail' : '';
  logLaunch('$step$extra', phase: 'boot');
}

/// Captura erros de construção de widget (muitas vezes resultam em tela preta sem mensagem)
/// e regista os primeiros frames em **debug**.
void installBootDiagnostics() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    logLaunch(
      'ErrorWidget — falha ao pintar subtree (causa comum de tela preta)',
      phase: 'boot',
      error: details.exception,
      stackTrace: details.stack,
    );
    return _BootErrorFallback(message: details.exceptionAsString());
  };

  if (kDebugMode) {
    var frameIndex = 0;
    void frameLog(Duration timeStamp) {
      if (frameIndex >= 24) return;
      bootTrace('frame', '#$frameIndex');
      frameIndex++;
      if (frameIndex == 24) {
        bootTrace(
          'frame_logging',
          'último log de frame (#23); callback mantém-se leve',
        );
      }
    }

    SchedulerBinding.instance.addPersistentFrameCallback(frameLog);
    bootTrace(
      'installBootDiagnostics',
      'ErrorWidget + log dos primeiros 24 frames (debug)',
    );
  }
}

class _BootErrorFallback extends StatelessWidget {
  const _BootErrorFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF2D0A12),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text(
                  '[BOOT] Erro ao construir um widget',
                  style: TextStyle(
                    color: Color(0xFFFF8A80),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
