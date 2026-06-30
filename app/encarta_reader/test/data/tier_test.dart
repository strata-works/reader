import 'package:encarta_reader/src/data/tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps CONT* tiers to labels', () {
    expect(tierBadge('CONTDLX'), 'Deluxe');
    expect(tierBadge('CONTSTD'), 'Standard');
    expect(tierBadge('CONTSTC'), 'Concise');
    expect(tierBadge('CONTKDC'), 'Kids');
  });

  test('unknown source falls back to the raw value', () {
    expect(tierBadge('WHATEVER'), 'WHATEVER');
    expect(tierBadge(''), '');
  });
}
