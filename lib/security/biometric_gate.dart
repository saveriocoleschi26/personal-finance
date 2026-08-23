import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import 'biometric_security.dart';

class BiometricGate extends StatefulWidget {
  final Widget child;

  const BiometricGate({
    super.key,
    required this.child,
  });

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  static const Duration _backgroundGrace = Duration(seconds: 15);

  bool _locked = false;
  bool _authenticating = false;
  bool _checking = true;
  DateTime? _backgroundedAt;

  BiometricSecurityController get _security =>
      BiometricSecurityController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _security.addListener(_securityChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareInitialState();
    });
  }

  @override
  void dispose() {
    _security.removeListener(_securityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _securityChanged() {
    if (!mounted) return;

    if (!_security.enabled) {
      setState(() {
        _locked = false;
        _checking = false;
      });
    }
  }

  Future<void> _prepareInitialState() async {
    if (!_security.enabled) {
      if (!mounted) return;
      setState(() {
        _locked = false;
        _checking = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _locked = true;
      _checking = false;
    });

    await _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating || !_security.enabled) return;

    setState(() {
      _authenticating = true;
    });

    final success = await _security.authenticateForUnlock();

    if (!mounted) return;

    setState(() {
      _authenticating = false;
      _locked = !success;
      if (success) {
        _backgroundedAt = null;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_security.enabled) return;

    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        !_authenticating) {
      _backgroundedAt ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed && !_authenticating) {
      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt == null) return;

      final elapsed = DateTime.now().difference(backgroundedAt);
      _backgroundedAt = null;

      if (elapsed >= _backgroundGrace) {
        if (mounted) {
          setState(() {
            _locked = true;
          });
        }
        unawaited(_unlock());
      }
    }
  }

  IconData get _lockIcon {
    if (Platform.isIOS) {
      return Icons.face_retouching_natural_rounded;
    }
    return Icons.fingerprint_rounded;
  }

  String get _unlockLabel {
    if (Platform.isIOS) {
      return le('Sblocca con Face ID', 'Unlock with Face ID');
    }
    return le(
      'Sblocca con impronta digitale',
      'Unlock with fingerprint',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_security.enabled || !_locked) {
      return widget.child;
    }

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    _lockIcon,
                    size: 38,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'P.F.',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  le(
                    'I tuoi dati sono protetti',
                    'Your data is protected',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _unlock,
                  icon: _authenticating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(_lockIcon),
                  label: Text(_unlockLabel),
                ),
                const SizedBox(height: 12),
                Text(
                  le(
                    'Se lo sblocco non parte, tocca il pulsante qui sopra.',
                    'If the unlock prompt does not appear, tap the button above.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
