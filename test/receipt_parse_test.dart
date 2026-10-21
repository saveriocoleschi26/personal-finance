// Test della lettura scontrini sul testo già riconosciuto (senza OCR né
// fotocamera): scontrini americani (Walmart, Target, Costco, ...) e uno
// italiano. Esegui con: flutter test test/receipt_parse_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/receipt_scan/receipt_scanner_service.dart';

class _Case {
  final String name;
  final String text;
  final double amount;
  final DateTime date;
  final String merchant;

  const _Case(this.name, this.text, this.amount, this.date, this.merchant);
}

final List<_Case> _cases = [
  _Case(
    'Walmart',
    r'''Walmart
Save money. Live better.
(805) 555-0142 Mgr. JANE DOE
2300 EXAMPLE BLVD
SAN LUIS OBISPO CA 93401
ST# 01234 OP# 00001234 TE# 05 TR# 01234
GV 2% MILK 007874201001 F 3.28
BANANAS 000000040119 KF 2.14
BREAD 007225003706 F 1.98
CHICKEN BRST 060538881237 F 9.47
SUBTOTAL 16.87
TAX 1 7.250 % 0.62
TOTAL 17.49
VISA CREDIT TEND 17.49
CHANGE DUE 0.00
# ITEMS SOLD 4
TC# 1234 5678 9012 3456 7890
10/05/26 14:32:11
''',
    17.49,
    DateTime(2026, 10, 5),
    r'''Walmart''',
  ),
  _Case(
    'Target',
    r'''TARGET
SAN LUIS OBISPO T-2759
1234 MADONNA RD
SAN LUIS OBISPO CA 93405
805-555-0100
10/06/2026 03:45 PM
085-12-0034 TIDE PODS 18.99 T
042-01-0129 CEREAL 4.29 F
110-05-0187 T-SHIRT 12.00 T
SUBTOTAL 35.28
T = CA TAX 7.7500 on 30.99 2.40
TOTAL 37.68
DEBIT CARD ************1234
AMOUNT: $37.68
Total Savings $2.00
''',
    37.68,
    DateTime(2026, 10, 6),
    r'''TARGET''',
  ),
  _Case(
    'Costco',
    r'''COSTCO
WHOLESALE
Santa Maria #1234
1801 EXAMPLE WAY
SANTA MARIA, CA 93454
Member 111888888888
E 1234567 KS WATER 4.99
E 1234568 ORG EGGS 8.49
E 1234569 CHICKEN 15.99
E 1234570 TOILET PAPER 22.99
SUBTOTAL 52.46
TAX 3.12
**** TOTAL 55.58
XXXXXXXXXXXX1234 CHIP
AMOUNT: $55.58
10/07/2026 14:32
Items Sold: 4
Total Number of Items Sold = 4
''',
    55.58,
    DateTime(2026, 10, 7),
    r'''COSTCO''',
  ),
  _Case(
    'Trader Joes',
    r'''TRADER JOE'S
#041 SAN LUIS OBISPO
3977 HIGUERA ST
SAN LUIS OBISPO CA 93401
Store 041 10/08/2026 11:05
BANANAS 0.99
ORG MILK 4.49
CHICKEN THIGHS 8.99
ITEMS IN TRANSACTION: 3
BALANCE TO PAY $14.47
VISA ****1234 $14.47
''',
    14.47,
    DateTime(2026, 10, 8),
    r'''TRADER JOE'S''',
  ),
  _Case(
    'Safeway',
    r'''SAFEWAY
Store #1234
Just for U
750 EXAMPLE AVE
Phone 805-555-0188
ORG BANANAS 1.29
SIGNATURE SELECT MILK 3.99
SUBTOTAL 5.28
CA CRV 0.10
SALES TAX 0.00
BALANCE DUE 5.38
DEBIT 5.38
Thank you for shopping at Safeway
10/09/2026 18:20
''',
    5.38,
    DateTime(2026, 10, 9),
    r'''SAFEWAY''',
  ),
  _Case(
    'Restaurant',
    r'''Bull's Tavern
123 Higuera St
San Luis Obispo, CA 93401
Server: Mike   Table 12   Guests 2
10/05/2026 7:42 PM
1 Burger 12.00
1 Fries 5.00
2 Draft Beer 14.00
Subtotal 31.00
Tax 2.40
Total 33.40
Tip suggestions
18% = $6.01   20% = $6.68   22% = $7.35
Tip ________
Total ________
Thank you!
''',
    33.4,
    DateTime(2026, 10, 5),
    r'''Bull's Tavern''',
  ),
  _Case(
    'Restaurant tip',
    r'''Giuseppe Cucina Rustica
876 Monterey St
SLO CA 93401
10/05/2026 8:10 PM
Pizza Margherita 17.00
Pasta 19.00
Subtotal 36.00
Tax 2.79
Total 38.79
VISA ****1234
Tip 7.00
Total with tip 45.79
''',
    45.79,
    DateTime(2026, 10, 5),
    r'''Giuseppe Cucina Rustica''',
  ),
  _Case(
    'Gas',
    r'''CHEVRON
1234 Example Hwy
Pump 04
10/10/2026 09:12
Regular Unleaded
Gallons 11.234
Price/Gal $4.899
Fuel Total $55.04
Total $55.04
VISA
''',
    55.04,
    DateTime(2026, 10, 10),
    r'''CHEVRON''',
  ),
  _Case(
    'CVS',
    r'''CVS pharmacy
1 EXAMPLE PLAZA
SAN LUIS OBISPO CA 93401
Rx pickup
ADVIL 8.99
SUBTOTAL 8.99
TAX 0.70
TOTAL 9.69
CASH 20.00
CHANGE 10.31
ExtraCare Savings 1.50
10/12/2026 16:20
''',
    9.69,
    DateTime(2026, 10, 12),
    r'''CVS pharmacy''',
  ),
  _Case(
    'Starbucks',
    r'''Starbucks Store #12345
123 Example St
Grande Latte 5.75
Croissant 3.95
Subtotal 9.70
Tax 0.75
Total $10.45
Visa ****1234
10/13/2026 08:03 AM
''',
    10.45,
    DateTime(2026, 10, 13),
    r'''Starbucks Store #12345''',
  ),
  _Case(
    '7-Eleven',
    r'''7-ELEVEN #25115
1234 EXAMPLE RD
SLO CA 93401
10/08/2026 21:44
SODA 2.19
CHIPS 3.29
SUBTOTAL 5.48
TAX 0.42
TOTAL 5.90
CASH 10.00
CHANGE 4.10
''',
    5.9,
    DateTime(2026, 10, 8),
    r'''7-ELEVEN #25115''',
  ),
  _Case(
    'Whole Foods',
    r'''WHOLE FOODS MARKET
Santa Barbara
223 State St
Items: 5
ORG AVOCADO 3.99
KOMBUCHA 3.49
SALAD 8.99
Subtotal 16.47
Tax 0.00
Total 16.47
Amazon Prime Savings -2.00
VISA 16.47
10/11/2026 12:58
''',
    16.47,
    DateTime(2026, 10, 11),
    r'''WHOLE FOODS MARKET''',
  ),
  _Case(
    'Italiano Esselunga',
    r'''ESSELUNGA
VIA ROMA 12 - FIRENZE
P.IVA 01234567890
LATTE 1,29
PANE 2,10
PASTA 1,45
TOTALE COMPLESSIVO 4,84
CONTANTI 5,00
RESTO 0,16
IVA 4% 0,19
05/10/2026 17:30
''',
    4.84,
    DateTime(2026, 10, 5),
    r'''ESSELUNGA''',
  ),
];

void main() {
  for (final c in _cases) {
    test(c.name, () {
      // App in italiano (englishApp: false): come sul telefono di Saverio.
      final r = ReceiptScannerService.parseText(c.text, englishApp: false);

      expect(r.amount, c.amount, reason: 'importo');
      expect(r.date, c.date, reason: 'data');

      final merchant = (r.merchant ?? '').toLowerCase().replaceAll(' ', '');
      final expected = c.merchant.toLowerCase().replaceAll(' ', '');
      expect(
        merchant.startsWith(expected.substring(0, 5)),
        isTrue,
        reason: 'esercente: letto "${r.merchant}", atteso "${c.merchant}"',
      );
    });
  }
}
