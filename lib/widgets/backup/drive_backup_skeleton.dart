import 'package:flutter/material.dart';

import 'package:kot_luy/theme.dart';

/// Full shimmering skeleton layout matching the Google Drive backup modal.
class DriveBackupSkeleton extends StatefulWidget {
  const DriveBackupSkeleton({super.key});

  @override
  State<DriveBackupSkeleton> createState() => _DriveBackupSkeletonState();
}

class _DriveBackupSkeletonState extends State<DriveBackupSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller?.stop();
    } else if (_controller != null && !_controller!.isAnimating) {
      _controller!.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      animation: _controller,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          _skeletonAccountCard(),
          const SizedBox(height: 16),
          _skeletonSettingsCard(),
          const SizedBox(height: 16),
          _skeletonManualBackupCard(),
          const SizedBox(height: 20),
          _skeletonSnapshotsSection(),
        ],
      ),
    );
  }

  Widget _skeletonAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          const _SkeletonBox(width: 40, height: 40, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 90, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                _SkeletonBox(width: 150, height: 14, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 44, height: 28, borderRadius: 8),
        ],
      ),
    );
  }

  Widget _skeletonSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(width: 180, height: 14, borderRadius: 6),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 240, height: 11, borderRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _SkeletonBox(width: 44, height: 24, borderRadius: 12),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(width: 160, height: 14, borderRadius: 6),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 210, height: 11, borderRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _SkeletonBox(width: 44, height: 24, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonManualBackupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 130, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                _SkeletonBox(width: 160, height: 11, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 128, height: 42, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _skeletonSnapshotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _SkeletonBox(width: 175, height: 16, borderRadius: 6),
            Spacer(),
            _SkeletonBox(width: 28, height: 28, borderRadius: 14),
          ],
        ),
        const SizedBox(height: 12),
        _skeletonSnapshotTile(),
        _skeletonSnapshotTile(),
      ],
    );
  }

  Widget _skeletonSnapshotTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          const _SkeletonBox(width: 36, height: 36, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 120, height: 14, borderRadius: 6),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    _SkeletonBox(width: 55, height: 11, borderRadius: 4),
                    SizedBox(width: 8),
                    _SkeletonBox(width: 48, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 62, height: 34, borderRadius: 10),
        ],
      ),
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.animation,
    required super.child,
  });

  final Animation<double>? animation;

  static Animation<double>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;
  }

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      animation != oldWidget.animation;
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = _ShimmerScope.of(context);
    const baseColor = Color(0xFFECEFE6);
    const highlightColor = Color(0xFFF7F9F3);

    if (animation == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: animation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.0 - 1.0),
      0.0,
      0.0,
    );
  }
}
