import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/main.dart';

void main() {
  testWidgets('Personal Finance si avvia correttamente',
      (WidgetTester tester) async {

    await tester.pumpWidget(const PersonalFinanceApp());

    expect(find.text('Personal Finance'), findsOneWidget);
    expect(find.text('Disponibile'), findsOneWidget);
    expect(find.text('Aggiungi movimento'), findsOneWidget);
  });
}