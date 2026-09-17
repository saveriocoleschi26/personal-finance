/// Risultato del parsing di uno scontrino.
///
/// Ogni campo è indipendente e può essere `null` se l'OCR non è riuscito
/// a riconoscerlo (es. perché la foto inquadra solo una parte dello
/// scontrino). La UI di conferma deve gestire questi casi lasciando il
/// campo vuoto, mai inventando un valore.
class ReceiptScanResult {
  final double? amount;
  final DateTime? date;
  final String? merchant;

  /// Testo grezzo estratto dall'OCR, utile per debug e per eventuali
  /// miglioramenti futuri del parsing.
  final String rawText;

  const ReceiptScanResult({
    required this.amount,
    required this.date,
    required this.merchant,
    required this.rawText,
  });

  bool get hasAnyData => amount != null || date != null || merchant != null;
}
