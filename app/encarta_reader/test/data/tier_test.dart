import 'package:encarta_reader/src/data/tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps bare CONT* tier codes to labels', () {
    expect(tierBadge('CONTDLX'), 'Deluxe');
    expect(tierBadge('CONTSTD'), 'Standard');
    expect(tierBadge('CONTSTC'), 'Concise');
    expect(tierBadge('CONTKDC'), 'Kids');
  });

  test('maps real corpus .AKC-suffixed source values to labels', () {
    expect(tierBadge('CONTDLX.AKC'), 'Deluxe');
    expect(tierBadge('CONTSTD.AKC'), 'Standard');
    expect(tierBadge('CONTSTC.AKC'), 'Concise');
    expect(tierBadge('CONTKDC.AKC'), 'Kids');
  });

  test('unknown source falls back to the raw value', () {
    expect(tierBadge('WHATEVER'), 'WHATEVER');
    expect(tierBadge(''), '');
  });
}
