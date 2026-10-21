import 'package:flutter/material.dart';

/// Una voce della schermata "Novità": icona, titolo e descrizione.
///
/// Per ora i testi sono in italiano e in inglese. Chi usa un'altra lingua
/// vede l'inglese (meglio dell'italiano per chi non lo legge); se in futuro
/// servono altre lingue basta aggiungere i campi qui e in [WhatsNewItem.title]
/// e [WhatsNewItem.body].
class WhatsNewItem {
  final IconData icon;
  final String titleIt;
  final String titleEn;
  final String bodyIt;
  final String bodyEn;

  const WhatsNewItem({
    required this.icon,
    required this.titleIt,
    required this.titleEn,
    required this.bodyIt,
    required this.bodyEn,
  });

  String title(bool italian) => italian ? titleIt : titleEn;
  String body(bool italian) => italian ? bodyIt : bodyEn;
}

/// Novità di ogni versione, indicate col NOME della versione (quello prima
/// del "+" in pubspec.yaml, es. 1.3.3), non col numero di build.
///
/// COME SI USA A OGNI RILASCIO: aggiungi qui una voce con la nuova versione
/// e le sue novità. Se per una versione non c'è nessuna voce (es. una
/// correzione minore) la schermata semplicemente non compare.
const Map<String, List<WhatsNewItem>> whatsNewByVersion = {
  '1.3.3': [
    WhatsNewItem(
      icon: Icons.touch_app_outlined,
      titleIt: 'Nuovo movimento dall\'icona',
      titleEn: 'New transaction from the icon',
      bodyIt:
          'Tieni premuta l\'icona di Liblo nella schermata Home del telefono e scegli «Nuovo movimento»: si apre subito la registrazione.',
      bodyEn:
          'Press and hold the Liblo icon on your Home Screen and choose "New transaction" to start recording right away.',
    ),
    WhatsNewItem(
      icon: Icons.picture_as_pdf_outlined,
      titleIt: 'Import da estratto conto più preciso',
      titleEn: 'More accurate statement import',
      bodyIt:
          'Liblo legge meglio gli estratti conto in PDF, riconosce entrate e uscite e controlla che i totali coincidano con quelli dell\'estratto, avvisandoti se qualcosa non torna.',
      bodyEn:
          'Liblo reads PDF statements more reliably, tells income from expenses and checks that the totals match the statement, warning you if something does not add up.',
    ),
    WhatsNewItem(
      icon: Icons.document_scanner_outlined,
      titleIt: 'Scontrini americani',
      titleEn: 'US receipts',
      bodyIt:
          'Migliorata la lettura di negozio, data e totale sugli scontrini degli Stati Uniti.',
      bodyEn:
          'Improved reading of the store, date and total on US receipts.',
    ),
  ],
};
