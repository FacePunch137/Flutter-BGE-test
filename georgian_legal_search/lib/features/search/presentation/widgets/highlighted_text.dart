import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const HighlightedText({
    Key? key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(text, style: style);
    }

    // A very basic stem/keyword extraction for highlighting
    // Split query by spaces
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length > 2).toList();

    if (terms.isEmpty) {
      return Text(text, style: style);
    }

    // Build regex pattern to match any of the terms
    final pattern = terms.map((t) => RegExp.escape(t)).join('|');
    final regex = RegExp(pattern, caseSensitive: false);

    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final defaultHighlightStyle = highlightStyle ??
        baseStyle.copyWith(backgroundColor: Colors.yellow.shade200, color: Colors.black);

    final defaultStyle = baseStyle;

    int currentIndex = 0;
    List<TextSpan> spans = [];

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: defaultStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: defaultHighlightStyle,
      ));
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
