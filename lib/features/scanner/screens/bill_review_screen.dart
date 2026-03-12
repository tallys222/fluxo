import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/bill_parser_service.dart';

class BillReviewScreen extends StatefulWidget {
  final BillParseResult parseResult;

  const BillReviewScreen({super.key, required this.parseResult});

  @override
  State<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends State<BillReviewScreen> {
  late List<BillTransaction> _transactions;
  final Set<int> _selected = {};
  bool _importing = false;

  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    // Começa só com débitos selecionados; créditos marcados separadamente
    _transactions = List.from(widget.parseResult.transactions);
    _selected.addAll(
      List.generate(_transactions.length, (i) => i)
          .where((i) => !_transactions[i].isCredit),
    );
  }

  double get _totalSelected => _transactions
      .whereIndexed((i, t) => _selected.contains(i))
      .fold(0, (sum, t) => sum + (t.isCredit ? -t.amount : t.amount));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
        title: const Text('Revisar Fatura'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _toggleAll,
            child: Text(
              _selected.length == _transactions.length ? 'Desmarcar todos' : 'Selecionar todos',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _transactions.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _transactions.length,
                    itemBuilder: (_, i) => _buildItem(i, isDark),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme, isDark),
    );
  }

  // ── Header com info da fatura ─────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final r = widget.parseResult;
    return Container(
      color: isDark ? const Color(0xFF16213E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.issuer ?? 'Fatura de Cartão',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (r.dueDate != null)
                  Text(
                    'Vencimento: ${r.dueDate}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currency.format(r.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Total da fatura',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Item da lista ─────────────────────────────────────────────────────

  Widget _buildItem(int index, bool isDark) {
    final t = _transactions[index];
    final selected = _selected.contains(index);
    final cardBg = isDark ? const Color(0xFF0F3460) : Colors.white;
    final creditColor = Colors.green.shade400;
    final debitColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('tx_$index'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) {
          setState(() {
            _transactions.removeAt(index);
            _selected.remove(index);
            // Reajusta índices acima
            final updated = <int>{};
            for (final i in _selected) {
              updated.add(i > index ? i - 1 : i);
            }
            _selected
              ..clear()
              ..addAll(updated);
          });
        },
        child: GestureDetector(
          onTap: () => _editItem(index),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: const Color(0xFFD4AF37), width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                // Checkbox
                Checkbox(
                  value: selected,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: (_) => setState(() {
                    selected ? _selected.remove(index) : _selected.add(index);
                  }),
                ),
                // Conteúdo
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (t.cardLast4 != null) ...[
                              Icon(Icons.credit_card, size: 12,
                                  color: isDark ? Colors.white38 : Colors.black38),
                              const SizedBox(width: 4),
                              Text(
                                '••${t.cardLast4}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              t.date,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Badge de categoria
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Color(int.parse(t.categoryColor.replaceAll('#', '0xFF'))).withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${t.categoryIcon} ${t.categoryName}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(int.parse(t.categoryColor.replaceAll('#', '0xFF'))),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (t.installmentInfo != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t.installmentInfo!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: t.isCredit ? creditColor : debitColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Valor
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '${t.isCredit ? '+' : '-'}${_currency.format(t.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: t.isCredit ? creditColor : debitColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('Nenhuma transação encontrada',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );

  // ── Bottom bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar(ThemeData theme, bool isDark) {
    final count = _selected.length;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count ${count == 1 ? 'item selecionado' : 'itens selecionados'}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              Text(
                _currency.format(_totalSelected.abs()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: count == 0 || _importing ? null : _import,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _importing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      count == 0
                          ? 'Selecione ao menos um item'
                          : 'Importar $count ${count == 1 ? 'lançamento' : 'lançamentos'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ações ─────────────────────────────────────────────────────────────

  void _toggleAll() {
    setState(() {
      if (_selected.length == _transactions.length) {
        _selected.clear();
      } else {
        _selected.addAll(List.generate(_transactions.length, (i) => i));
      }
    });
  }

  Future<void> _editItem(int index) async {
    final t = _transactions[index];
    final descCtrl = TextEditingController(text: t.description);
    final amtCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));

    final result = await showModalBottomSheet<BillTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        transaction: t,
        descController: descCtrl,
        amtController: amtCtrl,
      ),
    );

    if (result != null) {
      setState(() => _transactions[index] = result);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);

    final selected = _selected.map((i) => _transactions[i]).toList();

    // Retorna a lista de transações selecionadas para a tela anterior
    if (mounted) Navigator.of(context).pop(selected);
  }
}

// ── Extensão auxiliar ─────────────────────────────────────────────────────

extension _IterableIndexed<T> on Iterable<T> {
  Iterable<T> whereIndexed(bool Function(int index, T element) test) sync* {
    var i = 0;
    for (final e in this) {
      if (test(i, e)) yield e;
      i++;
    }
  }
}

// ── Bottom sheet de edição ────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final BillTransaction transaction;
  final TextEditingController descController;
  final TextEditingController amtController;

  const _EditSheet({
    required this.transaction,
    required this.descController,
    required this.amtController,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late bool _isCredit;

  @override
  void initState() {
    super.initState();
    _isCredit = widget.transaction.isCredit;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF16213E) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Editar lançamento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),

            // Descrição
            TextField(
              controller: widget.descController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Valor
            TextField(
              controller: widget.amtController,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
            const SizedBox(height: 16),

            // Tipo
            Row(
              children: [
                const Text('Tipo: '),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Débito'),
                  selected: !_isCredit,
                  onSelected: (_) => setState(() => _isCredit = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Crédito / Estorno'),
                  selected: _isCredit,
                  onSelected: (_) => setState(() => _isCredit = true),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      final raw = widget.amtController.text
                          .replaceAll('.', '')
                          .replaceAll(',', '.');
                      final amt = double.tryParse(raw) ?? widget.transaction.amount;
                      Navigator.pop(
                        context,
                        widget.transaction.copyWith(
                          description: widget.descController.text.trim(),
                          amount: amt,
                          isCredit: _isCredit,
                        ),
                      );
                    },
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}