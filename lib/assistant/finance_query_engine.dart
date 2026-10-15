/// Motore "a regole" dell'assistente di Liblo.
///
/// Risponde alle domande sulle spese dell'utente usando SOLO i dati già
/// presenti sul dispositivo e frasi preparate: nessun modello AI, nessuna
/// rete, nessuna cifra inventata. Ogni numero mostrato è calcolato qui,
/// dai totali per categoria del mese corrente e del mese precedente.
class _MonthEngine {
  /// Spese (solo uscite) per categoria nel mese corrente.
  final Map<String, double> currentMonth;

  /// Spese (solo uscite) per categoria nel mese precedente.
  final Map<String, double> previousMonth;

  /// Formattazione degli importi (valuta e separatori scelti dall'utente).
  final String Function(double) money;

  /// Etichette del mese analizzato: "questo mese" oppure "a settembre".
  final String cur;

  /// Etichetta del mese di confronto: "il mese scorso" oppure "ad agosto".
  final String prevLabel;

  const _MonthEngine({
    required this.currentMonth,
    required this.previousMonth,
    required this.money,
    this.cur = 'questo mese',
    this.prevLabel = 'il mese scorso',
  });

  String get _curCap => cur[0].toUpperCase() + cur.substring(1);

  /// "rispetto al mese scorso" / "rispetto ad agosto"
  String get _vsPrev => 'rispetto ${prevLabel.startsWith('il ') ? 'al ${prevLabel.substring(3)}' : prevLabel}';

  double get totalCurrent => currentMonth.values.fold(0.0, (a, b) => a + b);
  double get totalPrevious => previousMonth.values.fold(0.0, (a, b) => a + b);

  static const String helpReply =
      'Posso aiutarti con le spese registrate in Liblo. Prova a chiedermi, '
      'per esempio, dove spendi di più questo mese, quanto hai speso in '
      'totale, quale categoria è aumentata di più oppure come puoi '
      'risparmiare.';

  static const String offTopicReply =
      'Posso rispondere solo a domande sulle tue spese registrate in Liblo. '
      'Prova a chiedermi dove spendi di più o come risparmiare.';

  static const String _noTransactionsReply =
      'Qui ti mostro solo i totali per categoria. Per vedere le singole '
      'transazioni usa la Home di Liblo. Posso dirti dove spendi di più o '
      'come stanno cambiando le tue spese.';

  static const String _noBankReply =
      'Non ho accesso a conti, saldi o dati bancari: lavoro solo sulle '
      'spese registrate in Liblo.';

  static const String _noDataReplyNow =
      'Non ho ancora spese registrate per questo mese. Appena ne aggiungi '
      'qualcuna potrò risponderti.';

  String get _noDataReply => cur == 'questo mese'
      ? _noDataReplyNow
      : 'Non ho spese registrate $cur.';

  static const List<String> _adviceCues = [
    'risparm', 'ridurre', 'ridurr', 'tagliar', 'consigl', 'spendere meno',
    'spender meno', 'come posso', 'come faccio', 'dovrei', 'suggerisc',
    'aiutami', 'migliorare', 'limitare',
  ];

  /// Risponde sempre con un testo: dato, consiglio, rifiuto o aiuto.
  String answer(String question) {
    final q = _normalize(question);
    if (q.isEmpty) return helpReply;

    if (_isGreeting(q)) return 'Ciao! $helpReply';

    if (_matchesAny(q, ['transazion', 'movimenti'])) {
      return _noTransactionsReply;
    }
    if (_matchesAny(q, [
      'saldo', 'iban', 'mio conto', 'dati del conto', 'carta di credito',
    ])) {
      return _noBankReply;
    }

    final hasAdviceCue = _matchesAny(q, _adviceCues);
    final named = _findCategory(q);

    if (!hasAdviceCue && named == null && !_isFinanceRelated(q)) {
      return offTopicReply;
    }

    final noData = currentMonth.isEmpty && previousMonth.isEmpty;

    // "Dove ho speso di più?"
    if (_matchesAny(q, [
      'dove ho speso di piu', 'dove spendo di piu',
      'categoria in cui ho speso di piu', 'categoria in cui spendo di piu',
      'in quale categoria ho speso di piu', 'in quale categoria spendo di piu',
      'cosa ho speso di piu', 'cosa spendo di piu', 'spesa maggiore',
      'categoria con piu spese', 'spendo di piu',
    ]) && !hasAdviceCue && named == null) {
      final top = _topCategory(currentMonth);
      if (top == null) return _noDataReply;
      return '$_curCap hai speso di più in "${top.key}": '
          '${money(top.value)} (${_share(top.value)} della spesa totale).';
    }

    // "Quanto ho speso in totale?"
    if (_matchesAny(q, [
      'quanto ho speso in totale', 'quanto spendo in totale',
      'quanto ho speso in tutto', 'quanto spendo in tutto', 'spesa totale',
      'totale spese', 'totale delle spese', 'quanto ho speso questo mese',
      'quanto spendo questo mese', 'quanto ho speso', 'quanto spendo',
      'quanto ho speso nel mese', 'quante spese',
    ]) && named == null) {
      if (currentMonth.isEmpty) return _noDataReply;
      return '$_curCap hai speso in totale ${money(totalCurrent)}.';
    }

    // "Quale categoria è aumentata di più?"
    if (_matchesAny(q, [
      'quale categoria e aumentata di piu',
      'quale categoria e cresciuta di piu',
      'cosa e aumentato di piu', 'categoria cresciuta di piu',
      'categoria con aumento maggiore', 'aumentata di piu',
    ]) && named == null) {
      final inc = _topIncrease();
      if (inc == null || previousMonth.isEmpty) {
        return 'Non ho dati sufficienti sul mese precedente per fare un confronto.';
      }
      if (inc.deltaAbs <= 0.005) {
        return 'Nessuna categoria è aumentata $_vsPrev.';
      }
      return 'La categoria cresciuta di più è "${inc.category}": '
          '+${money(inc.deltaAbs)} (${_pct(inc.deltaPct)}) $_vsPrev.';
    }

    // Consigli (con o senza categoria)
    if (hasAdviceCue) return _adviceReply(q, named);

    // Dati su una categoria nominata
    if (named != null) {
      if (noData) return _noDataReply;
      final curr = currentMonth[named] ?? 0;
      final prev = previousMonth[named] ?? 0;
      if (_matchesAny(q, [
        'aumentat', 'diminuit', 'cambiat', 'variazione', 'confronto',
        'rispetto', 'mese scorso',
      ])) {
        final delta = curr - prev;
        if (delta.abs() < 0.005) {
          return '"$named" è rimasta invariata $_vsPrev '
              '(${money(curr)}).';
        }
        final pct = prev > 0 ? delta / prev * 100 : 100.0;
        final verb = delta > 0 ? 'aumentata' : 'diminuita';
        return '"$named" è $verb di ${money(delta.abs())} '
            '(${_pct(pct)}) $_vsPrev '
            '(da ${money(prev)} a ${money(curr)}).';
      }
      return 'In "$named" hai speso ${money(curr)} $cur.';
    }

    // Confronto generale col mese scorso
    if (_matchesAny(q, ['mese scorso', 'mese precedente', 'rispetto'])) {
      if (currentMonth.isEmpty || previousMonth.isEmpty) {
        return 'Non ho dati sufficienti per confrontare i due mesi.';
      }
      final delta = totalCurrent - totalPrevious;
      if (delta.abs() < 0.005) {
        return '$_curCap hai speso come $prevLabel '
            '(${money(totalCurrent)}).';
      }
      final pct = totalPrevious > 0 ? delta / totalPrevious * 100 : 100.0;
      final word = delta > 0 ? 'in più' : 'in meno';
      return '$_curCap hai speso ${money(totalCurrent)}, $prevLabel '
          '${money(totalPrevious)}: ${money(delta.abs())} $word '
          '(${_pct(pct)}).';
    }

    // Domanda sulle finanze ma non riconosciuta: panoramica + consiglio
    return _adviceReply(q, null);
  }

  // ---------------------------------------------------------------------
  // Consigli
  // ---------------------------------------------------------------------

  String _adviceReply(String q, String? category) {
    if (currentMonth.isEmpty) return _noDataReply;

    final buf = StringBuffer(_insight(category));
    final tips = <String>[];

    if (category != null) {
      tips.add(_tipFor(category, q));
    } else {
      final top = _topCategory(currentMonth);
      if (top != null) tips.add(_tipFor(top.key, q));
      final inc = _topIncrease();
      if (inc != null &&
          inc.deltaAbs > 0.005 &&
          inc.category != top?.key) {
        tips.add(_tipFor(inc.category, q));
      }
    }

    if (buf.isNotEmpty) buf.write('\n\n');
    buf.write(tips.join(' '));
    return buf.toString().trim();
  }

  String _insight(String? focus) {
    if (focus != null) {
      final curr = currentMonth[focus] ?? 0;
      final prev = previousMonth[focus] ?? 0;
      final delta = curr - prev;
      final shareTxt = '${_share(curr)} della spesa totale';
      if (previousMonth.isEmpty || delta.abs() < 0.005) {
        return 'In "$focus" $cur hai speso ${money(curr)} ($shareTxt).';
      }
      final pct = prev > 0 ? delta / prev * 100 : 100.0;
      final sign = delta > 0 ? '+' : '-';
      return 'In "$focus" $cur hai speso ${money(curr)} ($shareTxt): '
          '$sign${money(delta.abs())} (${_pct(pct)}) $_vsPrev.';
    }

    final top = _topCategory(currentMonth);
    if (top == null) return '';
    final buf = StringBuffer(
      '$_curCap hai speso di più in "${top.key}": ${money(top.value)} '
      '(${_share(top.value)} della spesa totale).',
    );
    final inc = _topIncrease();
    if (inc != null && inc.deltaAbs > 0.005 && previousMonth.isNotEmpty) {
      buf.write(
        ' La categoria cresciuta di più $_vsPrev è '
        '"${inc.category}": +${money(inc.deltaAbs)} (${_pct(inc.deltaPct)}).',
      );
    }
    return buf.toString();
  }

  static const List<(List<String>, List<String>)> _tipLibrary = [
    (
      ['ristorant', 'bar', 'caff', 'pizz', 'fuori'],
      [
        'Prova a fissare un tetto settimanale per pranzi e cene fuori e a '
            'preparare a casa qualche pasto in più.',
        'Portare il pranzo da casa un paio di giorni a settimana può '
            'alleggerire parecchio questa voce.',
      ],
    ),
    (
      ['spesa', 'aliment', 'supermerc', 'cibo'],
      [
        'Fai una lista prima di andare a fare la spesa e attieniti a quella: '
            'riduce gli acquisti d\'impulso.',
        'Confronta i prezzi e scegli i prodotti in offerta per ciò che usi '
            'spesso: su una voce ricorrente il risparmio si accumula.',
      ],
    ),
    (
      ['trasport', 'auto', 'benzin', 'carburant', 'mezzi'],
      [
        'Raggruppa gli spostamenti in meno viaggi e, dove possibile, usa i '
            'mezzi pubblici o vai a piedi.',
        'Controlla se un abbonamento ai mezzi conviene rispetto ai '
            'biglietti singoli.',
      ],
    ),
    (
      ['svago', 'intratten', 'cinema', 'diverti', 'uscite'],
      [
        'Scegli un budget fisso per lo svago e privilegia le attività '
            'gratuite o a basso costo per qualche settimana.',
        'Alterna le uscite a pagamento con serate a casa: il budget dura '
            'più a lungo.',
      ],
    ),
    (
      ['abbonament'],
      [
        'Rivedi gli abbonamenti attivi e disdici quelli che usi poco: sono '
            'spese che passano inosservate.',
        'Se due servizi si somigliano, tienine uno solo e riattiva l\'altro '
            'solo quando serve.',
      ],
    ),
    (
      ['shopping', 'vestit', 'abbigliament'],
      [
        'Prima di un acquisto non necessario aspetta qualche giorno: spesso '
            'la voglia passa.',
        'Fai una lista delle cose che ti servono davvero e fermati a quella.',
      ],
    ),
    (
      ['viagg', 'vacanz'],
      [
        'Prenota con anticipo e confronta le date: spostarsi di pochi '
            'giorni può cambiare molto il costo.',
      ],
    ),
    (
      ['casa', 'bollett', 'luce', 'gas', 'affitto'],
      [
        'Controlla le tariffe di luce e gas e i consumi: piccoli '
            'accorgimenti quotidiani riducono le bollette.',
      ],
    ),
    (
      ['telefon', 'internet'],
      [
        'Confronta la tua tariffa con le offerte attuali: spesso si paga '
            'più del necessario.',
      ],
    ),
    (
      ['salut', 'benesser', 'fitness', 'palestra'],
      [
        'Verifica che palestra e servizi per il benessere siano usati '
            'davvero: se no, valuta un piano più economico.',
      ],
    ),
    (
      ['regal'],
      [
        'Pianifica i regali con anticipo e fissa un tetto per ciascuno, '
            'così eviti spese all\'ultimo minuto.',
      ],
    ),
  ];

  static const List<String> _genericTips = [
    'Scegli la categoria in cui spendi di più e prova a ridurla di una '
        'piccola percentuale: i tagli graduali sono più facili da mantenere.',
    'Metti da parte una somma fissa a inizio mese e spendi il resto: '
        'risparmiare diventa automatico.',
  ];

  String _tipFor(String category, String q) {
    final c = _normalize(category);
    for (final entry in _tipLibrary) {
      if (entry.$1.any(c.contains)) {
        final tips = entry.$2;
        return tips[q.length % tips.length];
      }
    }
    return _genericTips[q.length % _genericTips.length];
  }

  // ---------------------------------------------------------------------
  // Riconoscimento della domanda
  // ---------------------------------------------------------------------

  bool _isGreeting(String q) {
    final w = q.split(RegExp(r'[^a-z0-9]+')).where((e) => e.isNotEmpty);
    if (w.isEmpty || w.length > 3) return false;
    const greetings = {'ciao', 'salve', 'buongiorno', 'buonasera', 'hey', 'ehi'};
    return greetings.contains(w.first);
  }

  bool _isFinanceRelated(String q) {
    const stems = [
      'risparm', 'spes', 'spend', 'budget', 'soldi', 'denaro', '€',
      'categori', 'questo mese', 'mese scorso', 'prossimo mese', 'mese precedente',
      'mese passato', 'scorso mese',
      'abbonament', 'entrat', 'uscit', 'liblo', 'tagliar', 'ridurre',
      'economi', 'pagament', 'bollett', 'guadagn', 'costi',
    ];
    return stems.any(q.contains);
  }

  static const Set<String> _stopWords = {
    'di', 'del', 'della', 'dei', 'da', 'in', 'con', 'per', 'la', 'il', 'le',
    'lo', 'gli', 'un', 'una', 'al', 'alla', 'e', 'ed',
  };

  // Parole troppo generiche per identificare da sole una categoria
  // composta (es. "Spesa alimentare" si trova con "alimentare", non con
  // l'espressione "la spesa").
  static const Set<String> _genericTokens = {'spesa'};

  bool _wordMatches(String token, String word) {
    if (token.length >= 6) {
      return word.startsWith(token.substring(0, token.length - 2));
    }
    return word == token;
  }

  /// Categoria nominata nella domanda. Tollera nomi parziali: "ristoranti"
  /// basta per "Ristoranti e bar".
  String? _findCategory(String q) {
    final names = {...currentMonth.keys, ...previousMonth.keys};
    if (names.isEmpty) return null;
    final words = q
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    String? best;
    double bestScore = 0;
    for (final name in names) {
      final n = _normalize(name);
      var score = 0.0;
      if (n.length >= 3 && q.contains(n)) {
        score = 100.0 + n.length;
      } else {
        final tokens = n
            .split(RegExp(r'[^a-z0-9]+'))
            .where((t) => t.length >= 3 && !_stopWords.contains(t))
            .toList();
        if (tokens.isEmpty) continue;
        final usable = tokens.length > 1
            ? tokens.where((t) => !_genericTokens.contains(t)).toList()
            : tokens;
        final matched =
            usable.where((t) => words.any((w) => _wordMatches(t, w))).length;
        if (matched == 0) continue;
        score = matched + matched / tokens.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = name;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------
  // Calcoli e formattazione
  // ---------------------------------------------------------------------

  MapEntry<String, double>? _topCategory(Map<String, double> data) {
    if (data.isEmpty) return null;
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first;
  }

  ({String category, double deltaAbs, double deltaPct})? _topIncrease() {
    ({String category, double deltaAbs, double deltaPct})? best;
    for (final cat in currentMonth.keys) {
      final curr = currentMonth[cat] ?? 0;
      final prev = previousMonth[cat] ?? 0;
      final delta = curr - prev;
      final pct = prev > 0 ? delta / prev * 100 : (curr > 0 ? 100.0 : 0.0);
      if (best == null || delta > best.deltaAbs) {
        best = (category: cat, deltaAbs: delta, deltaPct: pct);
      }
    }
    return best;
  }

  String _share(double value) {
    final total = totalCurrent;
    final share = total > 0 ? value / total * 100 : 0;
    return '${share.toStringAsFixed(0)}%';
  }

  String _pct(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)}%';

  String _normalize(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('’', "'");

  bool _matchesAny(String q, List<String> patterns) =>
      patterns.any((p) => q.contains(_normalize(p)));
}


/// Punto d'ingresso dell'assistente: capisce a quale mese si riferisce la
/// domanda ("settembre", "il mese scorso", "questo mese") e risponde con il
/// motore a regole su quel mese, confrontandolo con quello precedente.
class FinanceQueryEngine {
  /// Spese (solo uscite) per categoria, per mese. La chiave è
  /// `anno * 12 + (mese - 1)`, vedi [keyOf].
  final Map<int, Map<String, double>> byMonth;

  /// Data di oggi (serve a capire quale sia "questo mese").
  final DateTime now;

  final String Function(double) money;

  const FinanceQueryEngine({
    required this.byMonth,
    required this.now,
    required this.money,
  });

  static int keyOf(DateTime d) => d.year * 12 + d.month - 1;

  static const List<String> _monthNames = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio',
    'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u');

  /// Se [question] è un seguito breve che indica solo un mese
  /// ("sì ma il mese precedente?"), la unisce alla domanda precedente.
  static String resolveQuestion(String question, String? last) {
    if (last == null) return question;
    final q = _norm(question);
    final hasMonthCue = _monthCuePosition(q) != null;
    const substantive = [
      'spes', 'spend', 'risparm', 'categori', 'totale', 'aument', 'consigl',
      'quanto', 'dove', 'quale', 'come',
    ];
    final words = q.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);
    if (hasMonthCue &&
        !substantive.any(q.contains) &&
        words.length <= 8) {
      return '$last $question';
    }
    return question;
  }

  // Posizione (e mese) dell'ultimo riferimento temporale nella domanda.
  static ({int pos, int monthsBack, int? monthNumber})? _monthCuePosition(
    String q,
  ) {
    ({int pos, int monthsBack, int? monthNumber})? best;
    void consider(int pos, int back, int? number) {
      if (pos < 0) return;
      if (best == null || pos > best!.pos) {
        best = (pos: pos, monthsBack: back, monthNumber: number);
      }
    }

    for (final cue in [
      'mese scorso', 'scorso mese', 'mese precedente', 'mese passato',
    ]) {
      consider(q.lastIndexOf(cue), 1, null);
    }
    consider(q.lastIndexOf('questo mese'), 0, null);
    for (var i = 0; i < _monthNames.length; i++) {
      consider(q.lastIndexOf(_monthNames[i]), 0, i + 1);
    }
    return best;
  }

  String _label(int key) {
    final name = _monthNames[key % 12];
    final needsAd = name.startsWith('a');
    return '${needsAd ? 'ad' : 'a'} $name';
  }

  String answer(String question) {
    final q = _norm(question);
    final nowKey = keyOf(now);

    var targetKey = nowKey;
    var explicit = false;
    final cue = _monthCuePosition(q);
    if (cue != null) {
      if (cue.monthNumber != null) {
        final m = cue.monthNumber!;
        final year = m <= now.month ? now.year : now.year - 1;
        targetKey = year * 12 + m - 1;
        explicit = targetKey != nowKey;
      } else if (cue.monthsBack > 0) {
        targetKey = nowKey - cue.monthsBack;
        explicit = true;
      }
    }

    var note = '';
    if (!explicit && (byMonth[targetKey] ?? const {}).isEmpty) {
      for (var i = 1; i <= 12; i++) {
        if ((byMonth[targetKey - i] ?? const {}).isNotEmpty) {
          targetKey -= i;
          final name = _monthNames[targetKey % 12];
          note = 'Per questo mese non ci sono ancora spese registrate, quindi '
              'ti rispondo con ${targetKey == nowKey - 1 ? 'il mese scorso' : name}.\n\n';
          break;
        }
      }
    }

    final isNow = targetKey == nowKey;
    final engine = _MonthEngine(
      currentMonth: byMonth[targetKey] ?? const {},
      previousMonth: byMonth[targetKey - 1] ?? const {},
      money: money,
      cur: isNow ? 'questo mese' : _label(targetKey),
      prevLabel: isNow ? 'il mese scorso' : _label(targetKey - 1),
    );

    final reply = engine.answer(question);
    if (note.isEmpty || _isStatic(reply)) return reply;
    return '$note$reply';
  }

  static bool _isStatic(String reply) =>
      reply == _MonthEngine.offTopicReply ||
      reply == _MonthEngine.helpReply ||
      reply.startsWith('Ciao!') ||
      reply.startsWith('Non ho accesso a conti') ||
      reply.startsWith('Qui ti mostro solo i totali');
}
