import 'package:flutter/material.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLength;
  final TextStyle? style;
  final String moreLabel;
  final String lessLabel;
  final TextStyle? linkStyle;

  const ExpandableText({
    Key? key,
    required this.text,
    this.trimLength = 200,
    this.style,
    this.moreLabel = 'Devamını Oku',
    this.lessLabel = 'Daha Az Göster',
    this.linkStyle,
  }) : super(key: key);

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  late String firstPart;
  late String secondPart;
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.text.length > widget.trimLength) {
      firstPart = widget.text.substring(0, widget.trimLength);
      secondPart = widget.text.substring(widget.trimLength);
    } else {
      firstPart = widget.text;
      secondPart = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return secondPart.isEmpty
        ? Text(firstPart, style: widget.style)
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          expanded ? (firstPart + secondPart) : (firstPart + '...'),
          style: widget.style,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => expanded = !expanded),
          child: Text(
            expanded ? widget.lessLabel : widget.moreLabel,
            style: widget.linkStyle ??
                widget.style?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}
