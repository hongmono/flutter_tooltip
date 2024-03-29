import 'dart:math';

import 'package:flutter/material.dart';

import 'triangles/right_triangle.dart';
import 'triangles/down_triangle.dart';
import 'triangles/left_triangle.dart';
import 'triangles/upper_triangle.dart';

enum FlutterTooltipTriggerMode {
  /// Show tooltip when tap
  tap,

  /// Show tooltip when long press
  longPress,

  /// Show tooltip when double tap
  doubleTap,

  /// Show tooltip only controller
  manual,
}

enum FlutterTooltipDismissMode {
  /// Dismiss when tap outside of tooltip
  tapAnyWhere,

  /// Dismiss when tap inside of tooltip
  tapInside,

  /// Dismiss only controller
  manual,
}

class TooltipController extends ChangeNotifier {
  bool _isShow = false;

  bool get isShow => _isShow;

  void show() {
    _isShow = true;
    notifyListeners();
  }

  void dismiss() {
    _isShow = false;

    notifyListeners();
  }

  void toggle() => _isShow ? dismiss() : show();
}

class FlutterTooltip extends StatefulWidget {
  const FlutterTooltip({
    super.key,
    required this.message,
    required this.child,
    this.triangleColor = Colors.black,
    this.triangleSize = const Size(10, 10),
    this.targetPadding = 4,
    this.onShow,
    this.onDismiss,
    this.controller,
    this.messagePadding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    this.messageDecoration = const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(8))),
    this.messageStyle = const TextStyle(color: Colors.white, fontSize: 14),
    this.padding = const EdgeInsets.all(16),
    this.axis = Axis.vertical,
    this.triggerMode,
    this.dismissMode,
  });

  /// Message
  final String? message;

  /// Target Widget
  final Widget child;

  /// Triangle color
  final Color triangleColor;

  /// Triangle size
  final Size triangleSize;

  /// Gap between target and tooltip
  final double targetPadding;

  /// Show callback
  final VoidCallback? onShow;

  /// Dismiss callback
  final VoidCallback? onDismiss;

  /// Tooltip Controller
  final TooltipController? controller;

  /// Message Box padding
  final EdgeInsetsGeometry messagePadding;

  /// Message Box decoration
  final BoxDecoration messageDecoration;

  /// Message Box text style
  final TextStyle? messageStyle;

  /// Message Box padding
  final EdgeInsetsGeometry padding;

  /// Axis
  final Axis axis;

  /// Trigger mode
  final FlutterTooltipTriggerMode? triggerMode;

  /// dismiss mode
  final FlutterTooltipDismissMode? dismissMode;

  @override
  State<FlutterTooltip> createState() => _FlutterTooltipState();
}

class _FlutterTooltipState extends State<FlutterTooltip> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  late final TooltipController _controller;
  FlutterTooltipTriggerMode? _triggerMode;
  FlutterTooltipDismissMode? _dismissMode;

  final key = GlobalKey();
  final messageBoxKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);

    _controller = widget.controller ?? TooltipController();
    _controller.addListener(listener);

    initProperties();

    super.initState();
  }

  @override
  void didUpdateWidget(covariant FlutterTooltip oldWidget) {
    initProperties();

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    dismiss();
    _controller.removeListener(listener);
    if (widget.controller == null) {
      _controller.dispose();
    }

    _overlayEntry?.remove();
    _animationController.dispose();

    super.dispose();
  }

  void listener() {
    if (_controller.isShow == true) {
      show();
    } else {
      dismiss();
    }
  }

  void initProperties() {
    _triggerMode = switch (widget.controller) {
      null => widget.triggerMode ?? FlutterTooltipTriggerMode.longPress,
      _ => widget.triggerMode,
    };

    _dismissMode = switch (widget.controller) {
      null => widget.dismissMode ?? FlutterTooltipDismissMode.tapAnyWhere,
      _ => widget.dismissMode,
    };
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: switch (_triggerMode) {
          FlutterTooltipTriggerMode.tap => _controller.toggle,
          _ => null,
        },
        onLongPress: switch (_triggerMode) {
          FlutterTooltipTriggerMode.longPress => _controller.toggle,
          _ => null,
        },
        onDoubleTap: switch (_triggerMode) {
          FlutterTooltipTriggerMode.doubleTap => _controller.toggle,
          _ => null,
        },
        child: SizedBox(key: key, child: widget.child),
      ),
    );
  }

  void show() {
    if (widget.message == null) return;

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return;
    }

    final builder = _builder();

    if (builder == null) {
      return;
    }

    final Widget triangle = switch (builder.targetAnchor) {
      Alignment.bottomCenter => UpperTriangle(backgroundColor: widget.triangleColor),
      Alignment.topCenter => DownTriangle(backgroundColor: widget.triangleColor),
      Alignment.centerLeft => RightTriangle(backgroundColor: widget.triangleColor),
      Alignment.centerRight => LeftTriangle(backgroundColor: widget.triangleColor),
      _ => const SizedBox.shrink(),
    };

    final Offset triangleOffset = switch (builder.targetAnchor) {
      Alignment.bottomCenter => Offset(0, widget.targetPadding),
      Alignment.topCenter => Offset(0, -(widget.targetPadding)),
      Alignment.centerLeft => Offset(-(widget.targetPadding), 0),
      Alignment.centerRight => Offset(widget.targetPadding, 0),
      _ => Offset.zero,
    };

    final Offset messageBoxOffset = switch (builder.targetAnchor) {
      Alignment.bottomCenter => Offset(builder.offset.dx, widget.triangleSize.height + (widget.targetPadding) - 1),
      Alignment.topCenter => Offset(builder.offset.dx, -widget.triangleSize.height - (widget.targetPadding) + 1),
      Alignment.centerLeft => Offset(-(widget.targetPadding) - widget.triangleSize.width + 1, builder.offset.dy),
      Alignment.centerRight => Offset((widget.targetPadding) + widget.triangleSize.width - 1, builder.offset.dy),
      _ => Offset.zero,
    };

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return FadeTransition(
          opacity: _animation,
          child: GestureDetector(
            behavior: switch (_dismissMode) {
              FlutterTooltipDismissMode.tapAnyWhere => HitTestBehavior.opaque,
              FlutterTooltipDismissMode.tapInside => HitTestBehavior.deferToChild,
              _ => HitTestBehavior.deferToChild,
            },
            onTap: switch (_dismissMode) {
              FlutterTooltipDismissMode.tapAnyWhere => _controller.dismiss,
              FlutterTooltipDismissMode.tapInside => _controller.dismiss,
              _ => null,
            },
            child: Stack(
              children: [
                const SizedBox.expand(),
                CompositedTransformFollower(
                  link: _layerLink,
                  targetAnchor: builder.targetAnchor,
                  followerAnchor: builder.followerAnchor,
                  offset: messageBoxOffset,
                  child: builder.messageBox,
                ),
                CompositedTransformFollower(
                  link: _layerLink,
                  targetAnchor: builder.targetAnchor,
                  followerAnchor: builder.followerAnchor,
                  offset: triangleOffset,
                  child: SizedBox.fromSize(
                    size: widget.triangleSize,
                    child: triangle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (_overlayEntry != null) {
      Overlay.of(context).insert(_overlayEntry!);
      _animationController.forward();
      widget.onShow?.call();
    }
  }

  void dismiss() async {
    if (_overlayEntry != null) {
      await _animationController.reverse();
      _overlayEntry?.remove();
      _overlayEntry = null;
      widget.onDismiss?.call();
    }
  }

  ({Alignment targetAnchor, Alignment followerAnchor, Widget messageBox, Offset offset})? _builder() {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      Exception('RenderBox is null');
      return null;
    }

    final targetSize = renderBox.size;
    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetCenterPosition = Offset(targetPosition.dx + targetSize.width / 2, targetPosition.dy + targetSize.height / 2);
    final bool isLeft = targetCenterPosition.dx <= MediaQuery.of(context).size.width / 2;
    final bool isRight = targetCenterPosition.dx > MediaQuery.of(context).size.width / 2;
    final bool isBottom = targetCenterPosition.dy > MediaQuery.of(context).size.height / 2;
    final bool isTop = targetCenterPosition.dy <= MediaQuery.of(context).size.height / 2;

    final deviceWidth = MediaQuery.of(context).size.width;
    final remainWidth = switch (widget.axis) {
      Axis.vertical => deviceWidth - widget.padding.horizontal,
      Axis.horizontal when isRight => targetPosition.dx - (widget.padding.horizontal / 2) - widget.targetPadding - widget.triangleSize.width,
      Axis.horizontal when isLeft => deviceWidth - (targetPosition.dx + targetSize.width + widget.padding.horizontal / 2) - widget.targetPadding - widget.triangleSize.width,
      _ => deviceWidth,
    };

    final Widget messageBox = Material(
      type: MaterialType.transparency,
      child: Container(
        key: messageBoxKey,
        constraints: BoxConstraints(maxWidth: remainWidth),
        padding: widget.messagePadding,
        decoration: widget.messageDecoration,
        child: Text(widget.message ?? '', style: widget.messageStyle, softWrap: true, textScaler: TextScaler.noScaling),
      ),
    );

    Alignment targetAnchor = switch (widget.axis) {
      Axis.horizontal when isRight => Alignment.centerLeft,
      Axis.horizontal when isLeft => Alignment.centerRight,
      Axis.vertical when isTop => Alignment.bottomCenter,
      Axis.vertical when isBottom => Alignment.topCenter,
      _ => Alignment.center,
    };

    Alignment followerAnchor = switch (widget.axis) {
      Axis.horizontal when isRight => Alignment.centerRight,
      Axis.horizontal when isLeft => Alignment.centerLeft,
      Axis.vertical when isTop => Alignment.topCenter,
      Axis.vertical when isBottom => Alignment.bottomCenter,
      _ => Alignment.center,
    };

    final Size preferredSize = _textSize(widget.message ?? '', widget.messageStyle, remainWidth - widget.padding.horizontal) +
        Offset(
          widget.messagePadding.horizontal,
          widget.messagePadding.vertical,
        );

    final double overflowWidth = (preferredSize.width - targetSize.width) / 2;

    final edgeFromLeft = targetPosition.dx - overflowWidth;
    final edgeFromRight = MediaQuery.of(context).size.width - (targetPosition.dx + targetSize.width + overflowWidth);
    final edgeFromHorizontal = min(edgeFromLeft, edgeFromRight);

    double dx = 0;

    if (edgeFromHorizontal < widget.padding.horizontal / 2) {
      if (isLeft) {
        dx = (widget.padding.horizontal / 2) - edgeFromHorizontal;
      } else {
        dx = -(widget.padding.horizontal / 2) + edgeFromHorizontal;
      }
    }

    final double overflowHeight = (preferredSize.height - targetSize.height) / 2;

    final edgeFromTop = targetPosition.dy - overflowHeight;
    final edgeFromBottom = MediaQuery.of(context).size.height - (targetPosition.dy + targetSize.height + overflowHeight);
    final edgeFromVertical = min(edgeFromTop, edgeFromBottom);

    double dy = 0;

    if (edgeFromVertical < widget.padding.vertical / 2) {
      if (isTop) {
        dy = MediaQuery.of(context).padding.top + (widget.padding.vertical / 2) - edgeFromVertical;
      } else {
        dy = MediaQuery.of(context).padding.bottom - (widget.padding.vertical / 2) + edgeFromVertical;
      }
    }

    return (
      targetAnchor: targetAnchor,
      followerAnchor: followerAnchor,
      messageBox: messageBox,
      offset: Offset(dx, dy),
    );
  }

  Size _textSize(String text, TextStyle? style, double maxWidth) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(
        minWidth: 0,
        maxWidth: maxWidth,
      );

    return textPainter.size;
  }
}
