import 'package:flutter/material.dart';

import 'theme.dart';

// ===========================================================================
// Animation helpers
// ===========================================================================

/// Fades a child in while it slides up a little. Use [delay] to stagger a
/// list of items. Respects the phone's "reduce animations" setting.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
  CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Counts a number up from 0 (e.g. "12" or "76%").
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.suffix = '',
    this.style,
  });

  final num? value;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (value == null) return Text('--', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value!.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

// ===========================================================================
// Surfaces
// ===========================================================================

/// A soft surface. No outline: depth comes from a wide, faint shadow.
/// Presses shrink very slightly so taps feel responsive.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry margin;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return AnimatedScale(
      scale: (_down && widget.onTap != null) ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: widget.color ?? context.surfaceColor,
          borderRadius: radius,
          boxShadow: context.softShadow,
          border: context.isDark
              ? Border.all(color: context.hairline)
              : Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Several rows inside ONE rounded surface, separated by thin dividers.
/// Much calmer than a stack of separate boxes.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children, this.indent = 74});
  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: indent, color: context.hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A rounded square with an icon in it. Used as the leading icon of rows.
class IconBadge extends StatelessWidget {
  const IconBadge(
      {super.key, required this.icon, required this.color, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: context.isDark ? 0.28 : 0.20),
            color.withValues(alpha: context.isDark ? 0.12 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// One row inside a [ListGroup].
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Header
// ===========================================================================

/// Bold brand-gradient page header with softly floating shapes.
/// Name kept as GradientHeader so existing screens keep working.
/// Text is always white, because the gradient is dark/vivid in both modes.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: context.headerGradient),
        child: Stack(
          children: [
            const Positioned(
              right: -40,
              top: -34,
              child: FloatingBlob(size: 170, alpha: 0.09, seconds: 7),
            ),
            const Positioned(
              left: -36,
              bottom: -56,
              child: FloatingBlob(
                  size: 140, alpha: 0.07, seconds: 9, reverse: true),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 12, 24),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FadeSlideIn(
                            offset: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        height: 1.15,
                                        letterSpacing: -0.3,
                                        fontWeight: FontWeight.w800)),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(subtitle!,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 14)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    if (child != null) ...[
                      const SizedBox(height: 16),
                      child!
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft translucent circle that drifts slowly. Pure decoration.
class FloatingBlob extends StatefulWidget {
  const FloatingBlob({
    super.key,
    required this.size,
    this.alpha = 0.12,
    this.seconds = 8,
    this.reverse = false,
  });

  final double size;
  final double alpha;
  final int seconds;
  final bool reverse;

  @override
  State<FloatingBlob> createState() => _FloatingBlobState();
}

class _FloatingBlobState extends State<FloatingBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.reverse ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(dir * (v - 0.5) * 22, (0.5 - v) * 16),
          child: Transform.scale(scale: 0.94 + v * 0.12, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: widget.alpha),
        ),
      ),
    );
  }
}

// ===========================================================================
// Small pieces
// ===========================================================================

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color c;
    String label;
    if (s == 'ready') {
      c = AppColors.accent;
      label = 'Ready';
    } else if (s == 'failed') {
      c = AppColors.danger;
      label = 'Failed';
    } else {
      c = AppColors.warn;
      label = 'Processing';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style:
          TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Column(
                children: [
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.muted, height: 1.4)),
                ],
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(180, 48)),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.danger)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// One number in a [StatStrip].
class StatItem {
  const StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.suffix = '',
  });
  final IconData icon;
  final Color color;
  final num? value; // null shows "--"
  final String label;
  final String suffix;
}

/// Three (or more) key numbers inside ONE card, split by thin lines.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.items});
  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                    width: 1, thickness: 1, color: context.hairline),
              Expanded(
                child: Column(
                  children: [
                    IconBadge(
                        icon: items[i].icon, color: items[i].color, size: 38),
                    const SizedBox(height: 10),
                    AnimatedCount(
                      value: items[i].value,
                      suffix: items[i].suffix,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(items[i].label,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round icon button with a label under it (no box around it).
class QuickAction extends StatefulWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<QuickAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color,
                      Color.lerp(widget.color, Colors.black, 0.22)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 27),
              ),
              const SizedBox(height: 8),
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular score that fills up (and counts up) when it appears.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.pct,
    required this.color,
    this.size = 90,
    this.stroke = 10,
    this.sub,
  });

  final double? pct; // 0..100, null shows "--"
  final Color color;
  final double size;
  final double stroke;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final target = (pct ?? 0).clamp(0, 100).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v / 100,
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pct == null ? '--' : '${v.round()}%',
                    style: TextStyle(
                        fontSize: size * 0.22, fontWeight: FontWeight.w800)),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal progress bar with a label and a percentage (animated).
class PercentBar extends StatelessWidget {
  const PercentBar({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final double? percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final target = percent == null ? 0.0 : percent! / 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (percent != null)
                Text('${percent!.round()}%',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: target),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Loading skeletons (shown instead of a spinner while data loads)
// ===========================================================================

/// Gently pulses everything inside it. Respects "reduce animations".
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// One grey rounded block.
class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.quietFill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A placeholder that looks like one list row (icon + two lines of text).
class RowSkeleton extends StatelessWidget {
  const RowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Bone(width: 44, height: 44, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Bone(height: 14),
                SizedBox(height: 10),
                Bone(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-screen skeleton: one grouped card of placeholder rows.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          ListGroup(
            children: [for (var i = 0; i < count; i++) const RowSkeleton()],
          ),
        ],
      ),
    );
  }
}