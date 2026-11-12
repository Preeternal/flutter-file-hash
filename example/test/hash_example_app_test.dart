import 'package:flutter_file_hash_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders and toggles the mmap option without framework errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HashExampleApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final mmapOption = find.byType(CheckboxListTile);
    await tester.ensureVisible(mmapOption);
    expect(tester.widget<CheckboxListTile>(mmapOption).value, isFalse);

    await tester.tap(mmapOption);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<CheckboxListTile>(mmapOption).value, isTrue);
  });
}
