import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../preferences/biometric_lock_prefs.dart';
import '../theme/app_colors.dart';

/// Ao voltar do background, exige biometria se o utilizador ativou em Configurações.
///
/// O bloqueio é desenhado num [OverlayEntry] no [Overlay] do navigator raiz para
/// ficar **por cima** de modais e folhas (ex.: treino em execução).
class BiometricResumeLock extends StatefulWidget {
  const BiometricResumeLock({
    super.key,
    required this.child,
    this.rootNavigatorKey,
  });

  /// Overlay das rotas e bottom sheets — obrigatório quando o lock está fora do
  /// subtree do [Navigator] (ex.: [MaterialApp.builder]).
  final GlobalKey<NavigatorState>? rootNavigatorKey;

  final Widget? child;

  @override
  State<BiometricResumeLock> createState() => _BiometricResumeLockState();
}

class _BiometricResumeLockState extends State<BiometricResumeLock>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  var _wentToBackground = false;
  var _locked = false;
  var _checkingPref = true;
  var _prefOn = false;
  String? _error;
  OverlayEntry? _lockEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPref();
  }

  Future<void> _loadPref() async {
    final on = await BiometricLockPrefs.enabled;
    if (!mounted) return;
    setState(() {
      _prefOn = on;
      _checkingPref = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeLockOverlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wentToBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_reloadPrefAndMaybeLock());
    }
  }

  Future<void> _reloadPrefAndMaybeLock() async {
    final on = await BiometricLockPrefs.enabled;
    if (!mounted) return;
    setState(() => _prefOn = on);
    await _maybeLock();
  }

  Future<void> _maybeLock() async {
    if (!_prefOn || !_wentToBackground) return;
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    if (!supported || !canCheck) return;
    if (!mounted) return;
    setState(() {
      _locked = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncLockOverlay();
    });
  }

  void _refreshLockOverlay() => _lockEntry?.markNeedsBuild();

  void _syncLockOverlay() {
    if (!_locked) {
      _removeLockOverlay();
      return;
    }
    if (_lockEntry != null) return;
    final overlay =
        widget.rootNavigatorKey?.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _locked && _lockEntry == null) _syncLockOverlay();
      });
      return;
    }

    _lockEntry = OverlayEntry(
      maintainState: false,
      builder: (ctx) => Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 56,
                  color: AppColors.accentGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'App bloqueado',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use Face ID ou impressão digital para continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.accentPink,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(_lockEntry!);
  }

  void _removeLockOverlay() {
    _lockEntry?.remove();
    _lockEntry = null;
  }

  Future<void> _unlock() async {
    setState(() => _error = null);
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Desbloquear o Personal Gym',
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _locked = false;
          _wentToBackground = false;
        });
        _removeLockOverlay();
      } else {
        setState(() => _error = 'Autenticação cancelada ou falhou.');
        _refreshLockOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _refreshLockOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPref) {
      return widget.child ?? const SizedBox.shrink();
    }
    if (!_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _removeLockOverlay();
      });
    }
    return widget.child ?? const SizedBox.shrink();
  }
}
