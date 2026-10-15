import 'dart:async';

import 'package:flutter/material.dart';

import '../currency/app_currency.dart';
import '../database/database_service.dart';
import '../home_page.dart' show HomeColors;
import '../localization/app_language.dart';
import '../transaction/final_transaction.dart';
import 'finance_query_engine.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;

  const _ChatMessage(this.text, {required this.fromUser});
}

/// Chat dell'assistente di Liblo. Tutto avviene sul dispositivo: le
/// risposte nascono da calcoli sui dati locali e da frasi preparate,
/// nessun dato viene inviato altrove.
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _busy = false;
  Timer? _typeTimer;

  static const List<String> _suggestions = [
    'Dove ho speso di più questo mese?',
    'Quanto ho speso in totale?',
    'Quale categoria è aumentata di più?',
    'Come posso risparmiare il prossimo mese?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        l(
          'Ciao! Sono l\'assistente di Liblo. Posso rispondere a domande '
          'sulle tue spese e darti qualche idea per risparmiare. Tutto '
          'avviene su questo telefono: i tuoi dati non escono dal '
          'dispositivo.',
        ),
        fromUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<FinanceQueryEngine> _loadEngine() async {
    final now = DateTime.now();
    final db = DatabaseService.instance;

    final current = await db.getTransactionsForMonth(
      DateTime(now.year, now.month, 1),
    );
    final previous = await db.getTransactionsForMonth(
      DateTime(now.year, now.month - 1, 1),
    );

    return FinanceQueryEngine(
      currentMonth: _sumByCategory(current),
      previousMonth: _sumByCategory(previous),
      money: AppCurrencyController.instance.format,
    );
  }

  Map<String, double> _sumByCategory(List<FinanceTransaction> items) {
    final result = <String, double>{};
    for (final t in items) {
      if (t.isIncome) continue;
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String raw) async {
    final question = raw.trim();
    if (question.isEmpty || _busy) return;

    _controller.clear();
    setState(() {
      _busy = true;
      _messages.add(_ChatMessage(question, fromUser: true));
    });
    _scrollToBottom();

    String reply;
    try {
      final engine = await _loadEngine();
      reply = engine.answer(question);
    } catch (_) {
      reply = l(
        'Non sono riuscito a leggere le tue spese in questo momento. '
        'Riprova tra poco.',
      );
    }

    // Piccola pausa e scrittura progressiva, per non far comparire la
    // risposta all'improvviso.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() => _messages.add(const _ChatMessage('', fromUser: false)));
    final index = _messages.length - 1;
    final total = reply.length;
    final step = (total / 40).ceil().clamp(1, 1000);
    var shown = 0;

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      shown = (shown + step).clamp(0, total);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _messages[index] = _ChatMessage(
          reply.substring(0, shown),
          fromUser: false,
        );
      });
      _scrollToBottom();
      if (shown >= total) {
        timer.cancel();
        setState(() => _busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = HomeColors.of(context);

    return Scaffold(
      backgroundColor: hc.pageBackground,
      appBar: AppBar(
        backgroundColor: hc.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: hc.textPrimary,
        title: Text(
          l('Assistente Liblo'),
          style: TextStyle(
            color: hc.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _messages.length,
                itemBuilder: (context, i) => _bubble(hc, _messages[i]),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(
                    l(_suggestions[i]),
                    style: TextStyle(color: hc.teal, fontSize: 13),
                  ),
                  backgroundColor: hc.cardBackground,
                  side: BorderSide(color: hc.border),
                  onPressed: _busy ? null : () => _send(l(_suggestions[i])),
                ),
              ),
            ),
            _inputBar(hc),
          ],
        ),
      ),
    );
  }

  Widget _bubble(HomeColors hc, _ChatMessage m) {
    final user = m.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: user ? hc.teal : hc.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: user ? null : Border.all(color: hc.border),
        ),
        child: Text(
          m.text.isEmpty ? '…' : m.text,
          style: TextStyle(
            color: user ? Colors.white : hc.textPrimary,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _inputBar(HomeColors hc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              style: TextStyle(color: hc.textPrimary),
              decoration: InputDecoration(
                hintText: l('Chiedimi delle tue spese…'),
                hintStyle: TextStyle(color: hc.textSecondary),
                filled: true,
                fillColor: hc.cardBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: hc.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: hc.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: hc.teal),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: hc.teal),
            onPressed: _busy ? null : () => _send(_controller.text),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
