import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostels/main.dart';

void main() {
  testWidgets('app shell renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HostelsApp()));

    expect(find.text('Balaji Hostels'), findsOneWidget);
  });
}
