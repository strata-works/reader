import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:encarta_data/src/database.dart';
import 'package:test/test.dart';

void main() {
  test('EncartaDatabase wires drift codegen and runs a trivial query', () async {
    final db = EncartaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final row = await db.customSelect('SELECT 1 AS v').getSingle();
    expect(row.read<int>('v'), 1);
  });
}
