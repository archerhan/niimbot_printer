import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer/widgets/label_preview.dart';

/// 1x1 透明 PNG，仅用于让 Image.memory 能解码。
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  testWidgets('标签预览带圆角矩形边框', (tester) async {
    final bytes = Uint8List.fromList(base64Decode(_pngBase64));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: LabelPreview(imageBytes: bytes)),
        ),
      ),
    );
    await tester.pump();

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(LabelPreview),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.border, isA<Border>());
    expect(decoration.borderRadius, isA<BorderRadius>());
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft,
      const Radius.circular(10),
    );
    expect(decoration.color, Colors.white);
  });
}
