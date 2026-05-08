import 'package:flutter/material.dart';

class ResponsiveTableContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool thumbVisibility;
  final double compactBreakpoint;
  final double? minWidth;

  const ResponsiveTableContainer({
    super.key,
    required this.child,
    this.padding,
    this.thumbVisibility = false,
    this.compactBreakpoint = 900,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final targetMinWidth = minWidth ?? constraints.maxWidth;
        final isCompact = constraints.maxWidth < compactBreakpoint;

        return Scrollbar(
          thumbVisibility: thumbVisibility && isCompact,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: targetMinWidth),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: child,
              ),
            ),
          ),
        );
      },
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return content;
  }
}
