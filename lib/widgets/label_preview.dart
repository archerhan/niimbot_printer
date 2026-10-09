import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 标签预览：白底 + 圆角矩形边框。
class LabelPreview extends StatelessWidget {
  const LabelPreview({
    super.key,
    required this.imageBytes,
    this.height = 160,
  });

  final Uint8List imageBytes;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black54, width: 1.5),
      ),
      child: Image.memory(imageBytes, height: height, fit: BoxFit.contain),
    );
  }
}
