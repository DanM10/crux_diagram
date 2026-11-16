import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';

void main() {
  group('ShapeGroup value semantics', () {
    test('equal fields are equal and share a hash code', () {
      final group = ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']);
      final same = ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']);
      expect(same, group);
      expect(same.hashCode, group.hashCode);
    });

    test('id and member order take part in equality', () {
      final group = ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']);
      expect(ShapeGroup(id: 'g_02', shapeIds: ['s_01', 's_02']), isNot(group));
      expect(ShapeGroup(id: 'g_01', shapeIds: ['s_02', 's_01']), isNot(group));
      expect(
        ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02', 's_03']),
        isNot(group),
      );
    });

    test('shapeIds is an unmodifiable copy', () {
      final ids = ['s_01', 's_02'];
      final group = ShapeGroup(id: 'g_01', shapeIds: ids);
      ids.add('s_03');
      expect(group.shapeIds, ['s_01', 's_02']);
      expect(() => group.shapeIds.add('s_03'), throwsUnsupportedError);
    });

    test('toString names the id and members', () {
      final group = ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']);
      expect(group.toString(), contains('g_01'));
      expect(group.toString(), contains('s_02'));
    });
  });
}
