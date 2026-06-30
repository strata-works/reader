// packages/encarta_render/test/callbacks_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encarta_render/encarta_render.dart';

void main() {
  test('callback typedefs have the locked shapes', () {
    // ignore: prefer_function_declarations_over_variables — typed variable is the typedef shape assertion
    final AssetResolver ar = (inlineId, inlineType) => const SizedBox.shrink();
    int? tappedRefid;
    String? tappedPara;
    // ignore: prefer_function_declarations_over_variables — typed variable is the typedef shape assertion
    final XrefTap tap = (refid, {paraId}) {
      tappedRefid = refid;
      tappedPara = paraId;
    };
    // ignore: prefer_function_declarations_over_variables — typed variable is the typedef shape assertion
    final TitleForRefid t = (refid) => refid == 1 ? 'One' : null;

    expect(ar('GLYPH.DIB', 28), isA<Widget>());
    tap(7, paraId: 'p3');
    expect(tappedRefid, 7);
    expect(tappedPara, 'p3');
    expect(t(1), 'One');
    expect(t(2), isNull);
  });
}
