import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

void main() {
  test('default generator produces distinct prefixed ids', () {
    final next = defaultIdGenerator(prefix: 's');
    final ids = List.generate(1000, (_) => next());
    expect(ids.toSet(), hasLength(1000));
    expect(ids, everyElement(startsWith('s_')));
  });

  test('sequential generator is deterministic', () {
    final next = sequentialIdGenerator(prefix: 's');
    expect([next(), next(), next()], ['s_1', 's_2', 's_3']);
  });
}
