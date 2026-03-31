import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/futuristic_background.dart';
import '../../data/repositories/app_data_repository.dart';
import '../shell/main_shell.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final repo = context.read<AppDataRepository>();
    await repo.warmUp();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(MainShell.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: AppColors.splashMint,
          fontWeight: FontWeight.bold,
          fontSize: 32,
          letterSpacing: 0.4,
        );

    return Scaffold(
      backgroundColor: Colors.black,
      body: FuturisticBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Personal Trainer',
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
              const SizedBox(height: 12),
              Text(
                'Powered by Leonardo Peres',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.splashMint,
                  strokeWidth: 3.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
