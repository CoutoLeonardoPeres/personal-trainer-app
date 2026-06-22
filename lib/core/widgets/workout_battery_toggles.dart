import 'dart:async';

import 'package:flutter/material.dart';

import '../preferences/workout_runtime_prefs.dart';
import '../workout/ios_lock_screen_live_activity.dart';

class RestIntervalToggleIconButton extends StatefulWidget {
  const RestIntervalToggleIconButton({
    super.key,
    this.splashRadius = 18,
    this.iconSize = 20,
  });

  final double splashRadius;
  final double iconSize;

  @override
  State<RestIntervalToggleIconButton> createState() =>
      _RestIntervalToggleIconButtonState();
}

class _RestIntervalToggleIconButtonState
    extends State<RestIntervalToggleIconButton> {
  bool _enabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await WorkoutRuntimePrefs.isRestIntervalEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _loaded = true;
    });
  }

  Future<void> _toggle() async {
    final next = !_enabled;
    setState(() => _enabled = next);
    await WorkoutRuntimePrefs.setRestIntervalEnabled(next);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _enabled
          ? 'Desativar timer de intervalo'
          : 'Ativar timer de intervalo',
      onPressed: _loaded ? _toggle : null,
      splashRadius: widget.splashRadius,
      iconSize: widget.iconSize,
      icon: Icon(
        _enabled ? Icons.timer_outlined : Icons.timer_off_outlined,
        color: Colors.white.withValues(alpha: _enabled ? 0.95 : 0.72),
      ),
    );
  }
}

class LiveActivityToggleIconButton extends StatefulWidget {
  const LiveActivityToggleIconButton({
    super.key,
    this.splashRadius = 18,
    this.iconSize = 20,
  });

  final double splashRadius;
  final double iconSize;

  @override
  State<LiveActivityToggleIconButton> createState() =>
      _LiveActivityToggleIconButtonState();
}

class _LiveActivityToggleIconButtonState
    extends State<LiveActivityToggleIconButton> {
  bool _enabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await WorkoutRuntimePrefs.isLiveActivityEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _loaded = true;
    });
  }

  Future<void> _toggle() async {
    final next = !_enabled;
    setState(() => _enabled = next);
    await WorkoutRuntimePrefs.setLiveActivityEnabled(next);
    if (!next) {
      await IosLockScreenLiveActivity.endIfAny();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _enabled
          ? 'Desativar atividade ao vivo'
          : 'Ativar atividade ao vivo',
      onPressed: _loaded ? _toggle : null,
      splashRadius: widget.splashRadius,
      iconSize: widget.iconSize,
      icon: Icon(
        _enabled ? Icons.sensors_rounded : Icons.sensors_off_rounded,
        color: Colors.white.withValues(alpha: _enabled ? 0.95 : 0.72),
      ),
    );
  }
}

