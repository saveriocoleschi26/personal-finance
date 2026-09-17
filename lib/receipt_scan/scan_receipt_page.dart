import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_language.dart';
import 'receipt_scan_result.dart';
import 'receipt_scanner_service.dart';

/// Punto di ingresso della scansione scontrino: apre la fotocamera,
/// esegue l'OCR on-device e restituisce (via `Navigator.pop`) un
/// [ReceiptScanResult] da usare per pre-compilare `AddTransactionPage`.
///
/// Se l'utente annulla lo scatto, o l'OCR non riesce a leggere nulla di
/// utile, il pop avviene con `null`: il chiamante deve gestire questo
/// caso senza aprire una conferma vuota che sembri un errore.
class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Apriamo subito la fotocamera: questa schermata è solo un
    // contenitore che mostra lo stato di elaborazione.
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureAndScan());
  }

  Future<void> _captureAndScan() async {
    final picker = ImagePicker();

    XFile? photo;
    try {
      photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      photo = null;
    }

    if (photo == null) {
      // Utente ha annullato lo scatto (o permesso negato dal sistema).
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    ReceiptScanResult? result;
    try {
      result = await ReceiptScannerService.scan(photo.path);
    } catch (_) {
      result = null;
    }

    if (!mounted) return;

    if (result == null || !result.hasAnyData) {
      // Non siamo riusciti a leggere nulla: meglio avvisare e tornare
      // indietro piuttosto che aprire una conferma completamente vuota,
      // che l'utente potrebbe scambiare per un movimento a zero.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l('Non sono riuscito a leggere lo scontrino. Riprova o inserisci il movimento manualmente.'),
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // Schermata di solo stato: la fotocamera vera e propria è quella di
    // sistema aperta da image_picker.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    l('Lettura scontrino in corso...'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
