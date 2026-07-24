import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import 'scan_object_screen.dart';

/// Home base for a child in Home Adventure mode.
///
/// PHASE 2 SCOPE — deliberately minimal. This exists so the Family Code entry
/// flow has a real destination and the navigation is correct end to end.
/// Phase 3 replaces this body with the full responsive dashboard (sidebar,
/// daily mission, streak, adventure progress, treasure count, achievements)
/// driven by `GET /child/home/<child_id>`. The constructor is already shaped
/// for that, so the call sites won't need to change.
///
/// No parent controls appear here by design: no reports, no family-code
/// display, no account settings.
class ChildHomeScreen extends StatelessWidget {
  final String childId;
  final String nickname;
  final String? avatarId;
  final int avatarStage;

  const ChildHomeScreen({
    super.key,
    required this.childId,
    required this.nickname,
    this.avatarId,
    this.avatarStage = 1,
  });

  void _startExploring(BuildContext context) {
    // Phase 5 threads a LearningFlowMode and a completion anchor through here
    // so the guided childAdventure sequence returns to this screen. For now
    // it opens the existing scan flow unchanged.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanObjectScreen(childId: childId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChildAvatar(
                    avatarId: avatarId,
                    stage: avatarStage,
                    size: 132,
                    showStageBadge: true,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  Text(
                    'Hi, $nickname!',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    'Ready for a new adventure?',
                    textAlign: TextAlign.center,
                    style: AppTheme.body.copyWith(color: AppTheme.textLight),
                  ),
                  const SizedBox(height: AppTheme.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _startExploring(context),
                      icon: const Icon(Icons.photo_camera_rounded, size: 22),
                      label: const Text('Start Exploring'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.surface,
                        minimumSize: const Size(double.infinity, 64),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        textStyle: AppTheme.buttonText.copyWith(fontSize: 19),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  TextButton.icon(
                    // Unwinds the whole child session back to the welcome
                    // screen, so the next child starts from the family code.
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Finish for now'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
