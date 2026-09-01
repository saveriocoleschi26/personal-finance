import 'package:flutter/widgets.dart';

import '../database/database_service.dart';

class AppLanguageController extends ChangeNotifier with WidgetsBindingObserver {
  AppLanguageController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AppLanguageController instance = AppLanguageController._();

  static const String system = 'system';
  static const String italian = 'it';
  static const String english = 'en';

  String _preference = system;

  String get preference => _preference;

  String get systemLanguageCode {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == italian ? italian : english;
  }

  String get effectiveLanguageCode {
    if (_preference == system) return systemLanguageCode;
    return _preference;
  }

  bool get isEnglish => effectiveLanguageCode == english;

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_preference == system) {
      notifyListeners();
    }
  }

  Future<void> load() async {
    final saved = await DatabaseService.instance.getSetting('language_code');

    if (saved == system || saved == italian || saved == english) {
      _preference = saved!;
    }
  }

  Future<void> setPreference(String value) async {
    if (value != system && value != italian && value != english) return;
    if (_preference == value) return;

    _preference = value;
    notifyListeners();
    await DatabaseService.instance.setSetting('language_code', value);
  }

  List<String> get monthNames => isEnglish
      ? const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ]
      : const [
          'Gennaio',
          'Febbraio',
          'Marzo',
          'Aprile',
          'Maggio',
          'Giugno',
          'Luglio',
          'Agosto',
          'Settembre',
          'Ottobre',
          'Novembre',
          'Dicembre',
        ];

  List<String> get monthNamesForDates => isEnglish
      ? monthNames
      : const [
          'gennaio',
          'febbraio',
          'marzo',
          'aprile',
          'maggio',
          'giugno',
          'luglio',
          'agosto',
          'settembre',
          'ottobre',
          'novembre',
          'dicembre',
        ];

  String categoryLabel(String storedName) {
    if (!isEnglish) return storedName;

    return const {
          'Spesa': 'Groceries',
          'Spesa alimentare': 'Groceries',
          'Casa': 'Home',
          'Casa e bollette': 'Home & Bills',
          'Auto': 'Car',
          'Auto e trasporti': 'Transportation',
          'Svago': 'Entertainment',
          'Ristorante': 'Dining',
          'Ristoranti e bar': 'Dining Out',
          'Studio': 'Education',
          'Studio e formazione': 'Education',
          'Animali': 'Pets',
          'Viaggi': 'Travel',
          'Salute': 'Health',
          'Salute e benessere': 'Health & Wellness',
          'Fitness': 'Fitness',
          'Telefono': 'Phone',
          'Abbonamenti': 'Subscriptions',
          'Trasporti': 'Transport',
          'Bar': 'Coffee & drinks',
          'Regali': 'Gifts',
          'Lavoro': 'Work',
          'Shopping': 'Shopping',
          'Entrata': 'Income',
          'Altro': 'Other',
        }[storedName] ??
        storedName;
  }
}

String l(String italianText) {
  if (!AppLanguageController.instance.isEnglish) return italianText;
  return _english[italianText] ?? italianText;
}

String le(String italianText, String englishText) {
  return AppLanguageController.instance.isEnglish ? englishText : italianText;
}

String localizedCategory(String storedName) {
  return AppLanguageController.instance.categoryLabel(storedName);
}

const Map<String, String> _english = {
  'Impostazioni': 'Settings',
  'Personalizzazione': 'Personalization',
  'Categorie': 'Categories',
  'Crea, modifica e disattiva le categorie di spesa':
      'Create, edit, and disable expense categories',
  'Lingua': 'Language',
  'Scegli la lingua usata da Liblo': 'Choose the language used by Liblo',
  'Lingua dell’app': 'App language',
  'Automatico': 'Automatic',
  'Usa la lingua del telefono': 'Use your phone language',
  'Italiano': 'Italian',
  'Inglese': 'English',
  'Valuta': 'Currency',
  'Valuta dell’app': 'App currency',
  'Scegli la valuta mostrata da Liblo':
      'Choose the currency displayed by Liblo',
  'Euro (€)': 'Euro (€)',
  r'Dollaro statunitense ($)': r'US Dollar ($)',
  'La scelta cambia soltanto il simbolo mostrato. Gli importi non vengono convertiti.':
      'This setting only changes the displayed symbol. Amounts are not converted.',
  'Sicurezza': 'Security',
  'Proteggi Liblo': 'Protect Liblo',
  'Aiuto': 'Help',
  'Come funziona Liblo': 'How Liblo works',
  'Rivedi la guida rapida alle funzioni principali':
      'Review the quick guide to the main features',
  'Rivedi la guida completa alle funzioni principali':
      'Review the complete guide to the main features',
  'Home': 'Home',
  'Pianifica': 'Plan',
  'Salta': 'Skip',
  'Inizia': 'Get started',
  'Avanti': 'Next',
  'Tieni sotto controllo il mese': 'Stay on top of your month',
  'Il Disponibile considera ciò che hai già speso, le spese da pagare e i soldi che vuoi mettere da parte.':
      'Available money includes what you have already spent, upcoming expenses, and the money you want to set aside.',
  'Pianifica in anticipo': 'Plan ahead',
  'Inserisci spese previste, ricorrenti e scadenze a lungo termine. Liblo calcola quanto mettere da parte ogni mese prima delle scadenze.':
      'Add planned, recurring, and long-term expenses. Liblo works out how much to set aside each month before they are due.',
  'Registra i movimenti in un tap': 'Add transactions in one tap',
  'Usa il pulsante “+ Movimento” sempre visibile nella Home per aggiungere rapidamente un’entrata o una spesa.':
      'Use the “+ Transaction” button on Home to quickly add income or an expense.',
  'Benvenuto in Liblo': 'Welcome to Liblo',
  'Liblo ti mostra quanto puoi davvero spendere. Il Disponibile tiene conto delle entrate, delle spese e dei soldi che hai già destinato al futuro.':
      'Liblo shows you how much you can actually spend. Available money accounts for your income, expenses, and money already set aside for the future.',
  'Registra entrate e spese': 'Add income and expenses',
  'Tocca il pulsante “+” nella Home per aggiungere un movimento. Puoi scegliere la categoria, cambiare la data e modificare o eliminare i movimenti in seguito.':
      'Tap the “+” button on Home to add a transaction. You can choose a category, change the date, and edit or delete transactions later.',
  'Organizza il mese': 'Organize your month',
  'In Pianifica puoi inserire le spese previste, creare spese ricorrenti e scegliere quanti soldi mettere da parte come obiettivo di risparmio.':
      'In Plan, you can add planned expenses, create recurring expenses, and choose how much to set aside as your savings goal.',
  'Preparati alle scadenze': 'Prepare for upcoming expenses',
  'Aggiungi una scadenza a lungo termine, come bollo o assicurazione. Liblo divide l’importo tra i mesi precedenti e ti indica quanto mettere da parte.':
      'Add a long-term expense, such as car registration or insurance. Liblo spreads the amount across the preceding months and shows how much to set aside.',
  'Il saldo continua nel mese nuovo': 'Your balance carries into the new month',
  'Quando inizia un nuovo mese, il Disponibile positivo o negativo del mese precedente viene riportato automaticamente. Non serve creare un movimento.':
      'When a new month begins, the previous month’s positive or negative Available balance carries over automatically. You do not need to add a transaction.',
  'Controlla dove vanno i soldi': 'See where your money goes',
  'Dalla Home puoi cambiare mese, vedere il riepilogo, l’analisi per categoria e lo storico dei movimenti.':
      'From Home, you can switch months and view your summary, category breakdown, and transaction history.',
  'Personalizza Liblo': 'Personalize Liblo',
  'Nelle Impostazioni puoi gestire categorie, lingua, valuta e protezione biometrica. La scelta tra euro e dollari cambia il simbolo, non converte gli importi.':
      'In Settings, you can manage categories, language, currency, and biometric protection. Choosing euros or dollars changes the symbol but does not convert amounts.',
  'Modifica data': 'Edit date',
  'Data del movimento': 'Transaction date',
  'Annulla': 'Cancel',
  'Conferma': 'Confirm',
  'Inserisci un importo valido': 'Enter a valid amount',
  'Modifica movimento': 'Edit transaction',
  'Nuovo movimento': 'New transaction',
  'Importo': 'Amount',
  'Es. 25,50': 'e.g. 25.50',
  'Descrizione': 'Description',
  'Es. Cena con amici': 'e.g. Dinner with friends',
  'Data': 'Date',
  'Puoi registrare anche un movimento dimenticato di un mese precedente.':
      'You can also add a transaction you forgot from a previous month.',
  'Tipo di movimento': 'Transaction type',
  'Uscita': 'Expense',
  'Entrata': 'Income',
  'Spesa': 'Expense',
  'Salva modifiche': 'Save changes',
  'Salva movimento': 'Save transaction',
  'Obiettivo di risparmio': 'Savings goal',
  'Risparmio': 'Savings',
  'Quanto vuoi proteggere questo mese?': 'How much do you want to set aside this month?',
  'Salva': 'Save',
  'Categoria': 'Category',
  'Caricamento categorie...': 'Loading categories...',
  'Nessuna categoria disponibile': 'No categories available',
  'Disattivata': 'Disabled',
  'Modifica': 'Edit',
  'Elimina': 'Delete',
  'Riattiva': 'Reactivate',
  'Disattiva': 'Disable',
  'Aggiungi': 'Add',
  'Nuova categoria': 'New category',
  'Esiste già una categoria con questo nome.':
      'A category with this name already exists.',
  'Le vecchie operazioni manterranno questa categoria.':
      'Past transactions will keep this category.',
  'Le categorie attive compaiono quando aggiungi movimenti o spese pianificate. Disattivare una categoria non modifica lo storico.':
      'Active categories appear when you add transactions or planned expenses. Disabling a category does not change your history.',
  'Sempre disponibile': 'Always available',
  'Inserisci un nome per la categoria.': 'Enter a category name.',
  'Modifica categoria': 'Edit category',
  'Nome': 'Name',
  'Es. Animali': 'e.g. Pets',
  '“Altro” resta sempre disponibile come categoria di sicurezza.':
      '“Other” always stays available as a fallback category.',
  'Icona': 'Icon',
  'Colore': 'Color',
  'BUDGET GIORNALIERO': 'DAILY BUDGET',
  'RISULTATO DEL MESE': 'MONTH RESULT',
  'Hai chiuso il mese in positivo': 'You ended the month in the positive',
  'Le spese hanno superato le entrate': 'Your expenses were higher than your income',
  'Entrate e spese si sono compensate': 'Income and expenses balanced out',
  'Puoi spendere oggi': 'You can spend today',
  'È una stima di quanto puoi spendere oggi senza compromettere il resto del mese. Tiene conto del denaro disponibile e dei giorni che mancano alla fine del mese.':
      'This is an estimate of what you can spend today without affecting the rest of the month. It uses your available money and the days left in the month.',
  'Aggiungi movimento': 'Add transaction',
  'Disponibile': 'Available',
  'Saldo del mese': 'Month balance',
  'È quello che ti resta davvero da spendere dopo aver considerato le spese già fatte, quelle da pagare, i soldi da mettere da parte per le scadenze a lungo termine e il tuo obiettivo di risparmio.':
      'This is what you really have left to spend after your paid expenses, upcoming expenses, money set aside for long-term expenses, and your savings goal.',
  'Entrate': 'Income',
  'Uscite': 'Outgoings',
  'Soldi già destinati': 'Money already set aside',
  'Comprendono i soldi già spesi, quelli che serviranno per le spese future e quelli che hai scelto di mettere da parte. In questo modo Liblo non considera disponibili soldi che ti serviranno più avanti.':
      'This includes money already spent, money needed for upcoming expenses, and money you chose to set aside. Liblo does not count money you will need later as available.',
  'Percentuale spese/entrate': 'Expenses / income',
  'Nessuna entrata registrata': 'No income recorded',
  'Analisi spese': 'Spending breakdown',
  'Vedi quanto hai già speso e quanto hai già destinato.':
      'See what you have already spent and what you have set aside.',
  'Ultimi movimenti': 'Recent transactions',
  'Tocca un movimento per modificarlo o eliminarlo.':
      'Tap a transaction to edit or delete it.',
  'Storico mensile': 'Monthly history',
  'Totale destinato': 'Total set aside',
  'Per categoria': 'By category',
  'Niente da mostrare': 'Nothing to show',
  'Quando aggiungi spese o scegli dei soldi da mettere da parte, vedrai qui come sono distribuiti.':
      'When you add expenses or set money aside, you will see how it is distributed here.',
  'Nessun movimento': 'No transactions',
  'Nessun movimento registrato per questo mese.':
      'No transactions recorded for this month.',
  'Inserisci il tuo primo movimento': 'Add your first transaction',
  'Registra un\'entrata o una spesa per iniziare a vedere il tuo Disponibile.':
      'Record an income or an expense to start seeing your Available balance.',
  'Saldo mese precedente': 'Previous month balance',
  'Riportato automaticamente': 'Carried over automatically',
  'Ho capito': 'Got it',
  'Eliminare movimento?': 'Delete transaction?',
  'Organizza ciò che devi pagare e quanto vuoi mettere da parte.':
      'Organize what you need to pay and how much you want to set aside.',
  'FONDI DA METTERE DA PARTE': 'MONEY TO SET ASIDE',
  'Piano del mese': 'Monthly plan',
  'Spese previste del mese': 'Planned expenses',
  'Spese ricorrenti': 'Recurring expenses',
  'Soldi che vuoi mettere da parte': 'Money you want to set aside',
  'Scadenze a lungo termine': 'Long-term expenses',
  'Liblo divide ogni spesa tra i mesi prima della scadenza, così sai quanto mettere da parte ogni mese.':
      'Liblo spreads each expense across the months before it is due, so you know how much to set aside each month.',
  'questo mese': 'this month',
  'Prossime scadenze': 'Upcoming due dates',
  'Nessuna scadenza pianificata.': 'No upcoming due dates.',
  'Registra pagamento': 'Record payment',
  'Registra': 'Record',
  'Eliminare la spesa prevista?': 'Delete planned expense?',
  'Gestisci ricorrenza': 'Manage recurring expense',
  'ANCORA DA PAGARE': 'STILL TO PAY',
  'Voci del mese': 'This month',
  'Le ricorrenti vengono create automaticamente. Tocca una voce per le azioni disponibili.':
      'Recurring expenses are added automatically. Tap an item to see available actions.',
  'Nessuna spesa prevista': 'No planned expenses',
  'Aggiungi affitto, telefono, palestra o qualsiasi altra spesa che sai già di dover sostenere nel mese.':
      'Add rent, phone, gym, or any other expense you already know you will have this month.',
  'Pagata': 'Paid',
  'Ricorrente': 'Recurring',
  'Scadenza': 'Due date',
  'Seleziona la scadenza': 'Select due date',
  'Inserisci nome e importo validi': 'Enter a valid name and amount',
  'Modifica spesa prevista': 'Edit planned expense',
  'Nuova spesa prevista': 'New planned expense',
  'Es. Affitto': 'e.g. Rent',
  'Es. 500': 'e.g. 500',
  'Eliminare la ricorrenza?': 'Delete recurring expense?',
  'Metti in pausa': 'Pause',
  'Le tue ricorrenze': 'Your recurring expenses',
  'Affitto, telefono, palestra, streaming e altre spese che si ripetono ogni mese.':
      'Rent, phone, gym, streaming, and other expenses that repeat every month.',
  'Nessuna spesa ricorrente': 'No recurring expenses',
  'Aggiungi una spesa una sola volta e l’app la inserirà automaticamente nei mesi successivi.':
      'Add an expense once and the app will automatically add it to future months.',
  'senza scadenza finale': 'no end date',
  'In pausa': 'Paused',
  'Seleziona il mese di inizio': 'Select start month',
  'Seleziona il mese finale': 'Select end month',
  'Inserisci nome, importo e giorno del mese validi':
      'Enter a valid name, amount, and day of the month',
  'Il mese finale non può precedere quello iniziale':
      'The end month cannot be before the start month',
  'Modifica spesa ricorrente': 'Edit recurring expense',
  'Nuova spesa ricorrente': 'New recurring expense',
  'Es. Netflix': 'e.g. Netflix',
  'Importo mensile': 'Monthly amount',
  'Es. 12,99': 'e.g. 12.99',
  'Giorno di scadenza': 'Due day',
  'Es. 5': 'e.g. 5',
  'Se il mese ha meno giorni, useremo l’ultimo giorno disponibile.':
      'If the month is shorter, we will use its last available day.',
  'A partire da': 'Starting from',
  'Imposta un mese finale': 'Set an end month',
  'La spesa continuerà ogni mese': 'The expense will continue every month',
  'Mese finale': 'End month',
  'DA METTERE DA PARTE QUESTO MESE': 'TO SET ASIDE THIS MONTH',
  'Le tue scadenze': 'Your long-term expenses',
  'Tocca una voce per modificarla, registrare il pagamento o eliminarla.':
      'Tap an item to edit it, record the payment, or delete it.',
  'Nessuna scadenza a lungo termine': 'No long-term expenses',
  'Aggiungi bollo, assicurazione, abbonamenti o altre spese con una data di scadenza.':
      'Add car tax, insurance, subscriptions, or other expenses with a due date.',
  'Da pagare questo mese': 'Due this month',
  'Scaduta': 'Overdue',
  'Non devi ancora mettere da parte nulla': 'You do not need to set anything aside yet',
  'Eliminare la spesa?': 'Delete expense?',
  'La scadenza non può essere in un mese già trascorso':
      'The due date cannot be in a month that has already passed',
  'Modifica scadenza': 'Edit long-term expense',
  'Nuova scadenza': 'New long-term expense',
  'Es. Bollo auto': 'e.g. Car tax',
  'Data di scadenza': 'Due date',
  'Quanto mettere da parte': 'How much to set aside',
  'La scadenza è nello stesso mese: non ci sono mesi precedenti in cui mettere da parte questa somma.':
      'The expense is due this month, so there are no earlier months to spread this amount across.',
};
