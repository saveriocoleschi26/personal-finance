import 'package:flutter/material.dart';

import '../localization/app_language.dart';

// Testo in più lingue: codice lingua -> testo. I codici sono gli stessi
// di AppLanguageController (it, en-US, en-GB, fr, es, de, zh-Hans, pt-PT,
// pt-BR, ja, ar, ru). L'inglese britannico non ha voci proprie: usa
// l'inglese americano, come nel resto dell'app.
typedef WhatsNewText = Map<String, String>;

const String _it = AppLanguageController.italian;
const String _en = AppLanguageController.englishUS;
const String _fr = AppLanguageController.french;
const String _es = AppLanguageController.spanish;
const String _de = AppLanguageController.german;
const String _zh = AppLanguageController.chineseSimplified;
const String _ptPT = AppLanguageController.portuguesePT;
const String _ptBR = AppLanguageController.portugueseBR;
const String _ja = AppLanguageController.japanese;
const String _ar = AppLanguageController.arabic;
const String _ru = AppLanguageController.russian;

/// Sceglie il testo nella lingua corrente dell'app. Se manca la lingua
/// ripiega sull'inglese (inglese britannico compreso), poi sull'italiano.
String whatsNewText(WhatsNewText texts) {
  final lang = AppLanguageController.instance.effectiveLanguageCode;
  return texts[lang] ?? texts[_en] ?? texts[_it] ?? '';
}

/// Una voce della schermata "Novità": icona, titolo e descrizione.
class WhatsNewItem {
  final IconData icon;
  final WhatsNewText title;
  final WhatsNewText body;

  const WhatsNewItem({
    required this.icon,
    required this.title,
    required this.body,
  });
}

// Testi fissi della schermata (intestazione e pulsante).
const WhatsNewText whatsNewHeading = {
  _it: 'Novità di Liblo',
  _en: 'What\'s new in Liblo',
  _fr: 'Nouveautés de Liblo',
  _es: 'Novedades de Liblo',
  _de: 'Neuigkeiten in Liblo',
  _zh: 'Liblo 新功能',
  _ptPT: 'Novidades do Liblo',
  _ptBR: 'Novidades do Liblo',
  _ja: 'Libloの新機能',
  _ar: 'ما الجديد في Liblo',
  _ru: 'Что нового в Liblo',
};

// {v} viene sostituito con il numero di versione.
const WhatsNewText whatsNewVersionLabel = {
  _it: 'Versione {v}',
  _en: 'Version {v}',
  _fr: 'Version {v}',
  _es: 'Versión {v}',
  _de: 'Version {v}',
  _zh: '版本 {v}',
  _ptPT: 'Versão {v}',
  _ptBR: 'Versão {v}',
  _ja: 'バージョン {v}',
  _ar: 'الإصدار {v}',
  _ru: 'Версия {v}',
};

const WhatsNewText whatsNewContinue = {
  _it: 'Continua',
  _en: 'Continue',
  _fr: 'Continuer',
  _es: 'Continuar',
  _de: 'Weiter',
  _zh: '继续',
  _ptPT: 'Continuar',
  _ptBR: 'Continuar',
  _ja: '続ける',
  _ar: 'متابعة',
  _ru: 'Продолжить',
};

/// Novità di ogni versione, indicate col NOME della versione (quello prima
/// del "+" in pubspec.yaml, es. 1.3.3), non col numero di build.
///
/// COME SI USA A OGNI RILASCIO: aggiungi qui una voce con la nuova versione
/// e le sue novità (con tutte le lingue). Se per una versione non c'è
/// nessuna voce (es. una correzione minore) la schermata non compare.
const Map<String, List<WhatsNewItem>> whatsNewByVersion = {
  '1.3.3': [
    WhatsNewItem(
      icon: Icons.touch_app_outlined,
      title: {
        _it: 'Scorciatoie dall\'icona',
        _en: 'Shortcuts from the icon',
        _fr: 'Raccourcis depuis l\'icône',
        _es: 'Atajos desde el icono',
        _de: 'Kurzbefehle direkt vom Symbol',
        _zh: '图标快捷操作',
        _ptPT: 'Atalhos a partir do ícone',
        _ptBR: 'Atalhos pelo ícone',
        _ja: 'アイコンからのショートカット',
        _ar: 'اختصارات من الأيقونة',
        _ru: 'Быстрые действия с иконки',
      },
      body: {
        _it:
            'Tieni premuta l\'icona di Liblo nella schermata Home del telefono per aprire subito «Nuovo movimento» o «Scansiona scontrino».',
        _en:
            'Press and hold the Liblo icon on your Home Screen to jump straight to "New transaction" or "Scan receipt".',
        _fr:
            'Maintenez l\'icône de Liblo appuyée sur l\'écran d\'accueil pour ouvrir directement « Nouvelle opération » ou « Scanner le reçu ».',
        _es:
            'Mantén pulsado el icono de Liblo en la pantalla de inicio para ir directo a «Nuevo movimiento» o «Escanear ticket».',
        _de:
            'Halte das Liblo-Symbol auf dem Home-Bildschirm gedrückt, um direkt „Neue Buchung“ oder „Beleg scannen“ zu öffnen.',
        _zh: '在手机主屏幕上长按 Liblo 图标，即可直接打开“新建交易”或“扫描小票”。',
        _ptPT:
            'Prima sem soltar o ícone do Liblo no ecrã principal para ir diretamente a «Novo movimento» ou «Digitalizar recibo».',
        _ptBR:
            'Mantenha pressionado o ícone do Liblo na tela inicial para ir direto a «Nova transação» ou «Digitalizar recibo».',
        _ja:
            'ホーム画面でLibloのアイコンを長押しすると、「新しい取引」または「レシートをスキャン」をすぐに開けます。',
        _ar:
            'اضغط مطولًا على أيقونة Liblo في الشاشة الرئيسية للانتقال مباشرة إلى «حركة جديدة» أو «مسح الإيصال ضوئيًا».',
        _ru:
            'Нажмите и удерживайте значок Liblo на главном экране, чтобы сразу открыть «Новая операция» или «Сканировать чек».',
      },
    ),
    WhatsNewItem(
      icon: Icons.picture_as_pdf_outlined,
      title: {
        _it: 'Import da estratto conto più preciso',
        _en: 'More accurate statement import',
        _fr: 'Import des relevés plus précis',
        _es: 'Importación de extractos más precisa',
        _de: 'Genauerer Import von Kontoauszügen',
        _zh: '更精准的账单导入',
        _ptPT: 'Importação de extratos mais precisa',
        _ptBR: 'Importação de extratos mais precisa',
        _ja: 'より正確な明細のインポート',
        _ar: 'استيراد أدق لكشوف الحساب',
        _ru: 'Более точный импорт выписок',
      },
      body: {
        _it:
            'Liblo legge meglio gli estratti conto in PDF, riconosce entrate e uscite e controlla che i totali coincidano con quelli dell\'estratto, avvisandoti se qualcosa non torna.',
        _en:
            'Liblo reads PDF statements more reliably, tells income from expenses and checks that the totals match the statement, warning you if something does not add up.',
        _fr:
            'Liblo lit mieux les relevés PDF, distingue les entrées des sorties et vérifie que les totaux correspondent à ceux du relevé, en vous prévenant si quelque chose ne colle pas.',
        _es:
            'Liblo lee mejor los extractos en PDF, distingue ingresos y gastos y comprueba que los totales coincidan con los del extracto, avisándote si algo no cuadra.',
        _de:
            'Liblo liest PDF-Kontoauszüge zuverlässiger, unterscheidet Einnahmen und Ausgaben und prüft, ob die Summen mit dem Auszug übereinstimmen – und warnt dich, wenn etwas nicht stimmt.',
        _zh:
            'Liblo 能更准确地读取 PDF 账单，区分收入与支出，并核对总额是否与账单一致，如有不符会提醒你。',
        _ptPT:
            'O Liblo lê melhor os extratos em PDF, distingue entradas e saídas e verifica se os totais coincidem com os do extrato, avisando-o se algo não bater certo.',
        _ptBR:
            'O Liblo lê melhor os extratos em PDF, distingue entradas e saídas e confere se os totais batem com os do extrato, avisando você se algo não fechar.',
        _ja:
            'LibloはPDFの明細をより正確に読み取り、収入と支出を見分け、合計が明細と一致するかを確認します。合わない場合はお知らせします。',
        _ar:
            'يقرأ Liblo كشوف الحساب بصيغة PDF بدقة أفضل، ويميّز بين الإيرادات والمصروفات، ويتحقق من تطابق المجاميع مع الكشف، وينبّهك إذا كان هناك ما لا يتطابق.',
        _ru:
            'Liblo лучше читает выписки в PDF, отличает доходы от расходов и проверяет, совпадают ли итоги с выпиской, — а если что-то не сходится, предупреждает вас.',
      },
    ),
    WhatsNewItem(
      icon: Icons.document_scanner_outlined,
      title: {
        _it: 'Scontrini americani',
        _en: 'US receipts',
        _fr: 'Reçus américains',
        _es: 'Tickets de EE. UU.',
        _de: 'US-Belege',
        _zh: '美国小票',
        _ptPT: 'Recibos dos EUA',
        _ptBR: 'Recibos dos EUA',
        _ja: '米国のレシート',
        _ar: 'إيصالات الولايات المتحدة',
        _ru: 'Американские чеки',
      },
      body: {
        _it:
            'Migliorata la lettura di negozio, data e totale sugli scontrini degli Stati Uniti.',
        _en: 'Improved reading of the store, date and total on US receipts.',
        _fr:
            'Meilleure lecture du magasin, de la date et du total sur les reçus américains.',
        _es:
            'Mejor lectura de la tienda, la fecha y el total en los tickets de EE. UU.',
        _de:
            'Verbesserte Erkennung von Geschäft, Datum und Gesamtbetrag auf US-Belegen.',
        _zh: '改进了对美国小票上商店、日期和总额的识别。',
        _ptPT: 'Melhor leitura da loja, da data e do total nos recibos dos EUA.',
        _ptBR:
            'Leitura aprimorada da loja, da data e do total nos recibos dos EUA.',
        _ja: '米国のレシートで、店名・日付・合計金額の読み取りを改善しました。',
        _ar:
            'تحسين قراءة اسم المتجر والتاريخ والإجمالي في إيصالات الولايات المتحدة.',
        _ru:
            'Улучшено распознавание магазина, даты и итоговой суммы на американских чеках.',
      },
    ),
  ],
};
