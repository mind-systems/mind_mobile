import 'package:flutter/material.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/TimelineStep.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';

class BreathTimelineWidget extends StatefulWidget {
  final List<TimelineStep> steps;
  final String? activeStepId;
  final ScrollController scrollController;
  final BreathSessionStatus? status;

  final double itemHeight;
  final double fadeExtent;

  const BreathTimelineWidget({
    super.key,
    required this.steps,
    required this.activeStepId,
    required this.scrollController,
    this.status,
    this.itemHeight = 48.0,
    this.fadeExtent = 0.15, // доля высоты под fade сверху/снизу
  });

  @override
  State<BreathTimelineWidget> createState() => BreathTimelineWidgetState();
}

class BreathTimelineWidgetState extends State<BreathTimelineWidget> {
  // Карта для хранения GlobalKey каждого элемента
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _updateKeys();
  }

  @override
  void didUpdateWidget(BreathTimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем ключи если список шагов изменился
    if (widget.steps != oldWidget.steps) {
      _updateKeys();
    }
  }

  void _updateKeys() {
    for (final step in widget.steps) {
      if (step.id != null && !_itemKeys.containsKey(step.id!)) {
        _itemKeys[step.id!] = GlobalKey();
      }
    }
  }

  /// Получить Y-координату элемента по ID
  double? getItemOffsetById(String id) {
    final key = _itemKeys[id];
    if (key == null) return null;

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    // Получаем позицию относительно ListView (который является context этого виджета или его частью)
    // В данном случае context.findRenderObject() вернет RenderBox всего BreathTimelineWidget
    final listRenderBox = context.findRenderObject() as RenderBox?;
    if (listRenderBox == null) return null;

    final offset = renderBox.localToGlobal(Offset.zero, ancestor: listRenderBox);
    return offset.dy;
  }

  @override
  Widget build(BuildContext context) {
    final isPausedOrComplete =
        widget.status == BreathSessionStatus.pause ||
            widget.status == BreathSessionStatus.complete;

    final isComplete = widget.status == BreathSessionStatus.complete;

    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: isComplete ? 0.5 : 1.0,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final fade = widget.fadeExtent.clamp(0.0, 0.4);
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [
                0.0,
                fade,
                1.0 - fade,
                1.0,
              ],
            ).createShader(rect);
          },
          child: _buildList(isPausedOrComplete),
        ),
      ),
    );
  }

  Widget _buildList(bool isPausedOrComplete) {
    return ListView.builder(
      controller: widget.scrollController,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: widget.itemHeight),
      itemCount: widget.steps.length,
      itemBuilder: (context, index) {
        final step = widget.steps[index];
        final isActive = step.id == widget.activeStepId;

        if (step.type == TimelineStepType.separator) {
          return _buildSeparator(step);
        }

        return SizedBox(
          key: step.id != null ? _itemKeys[step.id!] : null,
          height: widget.itemHeight,
          child: _TimelineItem(
            step: step,
            index: index,
            isActive: isActive,
            isPausedOrComplete: isPausedOrComplete,
          ),
        );
      },
    );
  }

  Widget _buildSeparator(TimelineStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        height: 1,
        color: Colors.white.withValues(alpha: 0.15),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TimelineStep step;
  final int index;
  final bool isActive;
  final bool isPausedOrComplete;

  const _TimelineItem({
    required this.step,
    required this.index,
    required this.isActive,
    required this.isPausedOrComplete,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isActive ? 1.0 : 0.6;
    final scale = isActive ? 1.15 : 1.0;
    final color =
    isActive ? const Color(0xFF00D9FF) : Colors.white.withValues(alpha: 0.45);
    final textStyle = TextStyle(
      fontSize: isActive ? 22 : 16,
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      color: color,
      letterSpacing: 0.5,
    );

    return Center(
      child: AnimatedScale(
        scale: scale,
        duration:
        isPausedOrComplete ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: opacity,
          duration:
          isPausedOrComplete ? Duration.zero : const Duration(milliseconds: 280),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_phaseName(step.type), style: textStyle),
              const SizedBox(width: 6),
              Text('${step.duration ?? 0}', style: textStyle),
            ],
          ),
        ),
      ),
    );
  }

  String _phaseName(TimelineStepType type) {
    switch (type) {
      case TimelineStepType.inhale: return 'Inhale';
      case TimelineStepType.hold: return 'Hold';
      case TimelineStepType.exhale: return 'Exhale';
      case TimelineStepType.rest: return 'Rest';
      case TimelineStepType.separator: return '';
    }
  }
}
