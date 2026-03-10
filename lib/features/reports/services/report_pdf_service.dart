import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/reports_provider.dart';
import '../../transactions/models/transaction_model.dart';

class ReportPdfService {
  static const _primaryColor = PdfColor.fromInt(0xFF00C896); // AppColors.accent
  static const _expenseColor = PdfColor.fromInt(0xFFEF4444);
  static const _incomeColor  = PdfColor.fromInt(0xFF00C896);
  static const _bgDark       = PdfColor.fromInt(0xFF1A2332);
  static const _surface      = PdfColor.fromInt(0xFF1E2D3D);
  static const _textPrimary  = PdfColor.fromInt(0xFFE8EDF2);
  static const _textSecond   = PdfColor.fromInt(0xFF8A9BB0);
  static const _divider      = PdfColor.fromInt(0xFF2A3A4D);

  /// Gera o PDF e retorna o arquivo salvo.
  Future<File> generate({
    required ReportsData data,
    required ReportPeriod period,
    required List<TransactionModel> transactions,
  }) async {
    final pdf = pw.Document();
    final periodLabel = _periodLabel(period);
    final now = DateTime.now();
    final generatedAt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _bgDark),
          ),
        ),
        build: (context) => [
          // ── Capa / Header ──────────────────────────────────────────────
          _buildHeader(periodLabel, generatedAt),
          pw.SizedBox(height: 24),

          // ── KPIs ───────────────────────────────────────────────────────
          _buildKpiRow(data),
          pw.SizedBox(height: 24),

          // ── Evolução mensal ────────────────────────────────────────────
          if (data.last6Months.length > 1) ...[
            _buildSectionTitle('Evolução Mensal'),
            pw.SizedBox(height: 12),
            _buildMonthlyTable(data.last6Months),
            pw.SizedBox(height: 24),
          ],

          // ── Despesas por categoria ─────────────────────────────────────
          if (data.expensesByCategory.isNotEmpty) ...[
            _buildSectionTitle('Despesas por Categoria'),
            pw.SizedBox(height: 12),
            _buildCategoryTable(data.expensesByCategory, data.totalExpense, isExpense: true),
            pw.SizedBox(height: 24),
          ],

          // ── Receitas por categoria ─────────────────────────────────────
          if (data.incomeByCategory.isNotEmpty) ...[
            _buildSectionTitle('Receitas por Categoria'),
            pw.SizedBox(height: 12),
            _buildCategoryTable(data.incomeByCategory, data.totalIncome, isExpense: false),
            pw.SizedBox(height: 24),
          ],

          // ── Lista de transações ────────────────────────────────────────
          _buildSectionTitle('Lançamentos do Período'),
          pw.SizedBox(height: 12),
          _buildTransactionTable(transactions),

          // ── Rodapé ─────────────────────────────────────────────────────
          pw.SizedBox(height: 32),
          _buildFooter(),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'fluxo_relatorio_${DateFormat('yyyy_MM').format(now)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Builders ────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(String period, String generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _primaryColor, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('FLUXO',
                  style: pw.TextStyle(
                    color: _primaryColor,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 3,
                  )),
              pw.SizedBox(height: 4),
              pw.Text('Relatório Financeiro',
                  style: pw.TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  )),
              pw.SizedBox(height: 2),
              pw.Text(period,
                  style: pw.TextStyle(color: _textSecond, fontSize: 11)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Gerado em',
                  style: pw.TextStyle(color: _textSecond, fontSize: 10)),
              pw.Text(generatedAt,
                  style: pw.TextStyle(color: _textPrimary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildKpiRow(ReportsData data) {
    final savingsRate = data.savingsRate;
    final savingsColor = savingsRate >= 0 ? _incomeColor : _expenseColor;

    return pw.Row(children: [
      pw.Expanded(child: _kpiCard('Receitas', _fmt(data.totalIncome), _incomeColor)),
      pw.SizedBox(width: 10),
      pw.Expanded(child: _kpiCard('Despesas', _fmt(data.totalExpense), _expenseColor)),
      pw.SizedBox(width: 10),
      pw.Expanded(child: _kpiCard(
        'Saldo',
        _fmt(data.totalIncome - data.totalExpense),
        savingsColor,
      )),
      pw.SizedBox(width: 10),
      pw.Expanded(child: _kpiCard(
        'Taxa poupança',
        '${savingsRate.toStringAsFixed(1)}%',
        savingsColor,
      )),
    ]);
  }

  pw.Widget _kpiCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(color: _textSecond, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  color: color, fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            )),
        pw.SizedBox(height: 6),
        pw.Divider(color: _divider, thickness: 1),
      ],
    );
  }

  pw.Widget _buildMonthlyTable(List<MonthlyBalance> months) {
    final headers = ['Mês', 'Receitas', 'Despesas', 'Saldo'];
    final rows = months.map((m) {
      final balance = m.balance;
      return [
        DateFormat('MMM/yy', 'pt_BR').format(m.month),
        _fmt(m.income),
        _fmt(m.expense),
        _fmt(balance),
      ];
    }).toList();

    return _buildTable(headers, rows, columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(3),
      3: const pw.FlexColumnWidth(3),
    }, colorCell: (row, col) {
      if (col == 3) {
        final balance = months[row].balance;
        return balance >= 0 ? _incomeColor : _expenseColor;
      }
      if (col == 1) return _incomeColor;
      if (col == 2) return _expenseColor;
      return _textPrimary;
    });
  }

  pw.Widget _buildCategoryTable(
    List<CategorySummary> cats,
    double total, {
    required bool isExpense,
  }) {
    final headers = ['Categoria', 'Valor', '% do Total', 'Transações'];
    final rows = cats.map((c) => [
      c.name,
      _fmt(c.amount),
      '${c.percentage.toStringAsFixed(1)}%',
      '${c.count}',
    ]).toList();

    final barColor = isExpense ? _expenseColor : _incomeColor;

    return pw.Column(children: [
      _buildTable(headers, rows, columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      }),
      pw.SizedBox(height: 12),
      // Mini bar chart
      ...cats.take(8).map((c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(c.name,
                style: pw.TextStyle(color: _textSecond, fontSize: 9),
                maxLines: 1),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Stack(children: [
              pw.Container(height: 8, width: 200,
                  decoration: pw.BoxDecoration(color: _divider, borderRadius: pw.BorderRadius.circular(4))),
              pw.Container(
                width: (200 * (c.percentage / 100).clamp(0.01, 1.0)),
                height: 8,
                decoration: pw.BoxDecoration(
                  color: barColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ]),
          ),
          pw.SizedBox(width: 6),
          pw.SizedBox(
            width: 44,
            child: pw.Text('${c.percentage.toStringAsFixed(1)}%',
                style: pw.TextStyle(color: _textSecond, fontSize: 9),
                textAlign: pw.TextAlign.right),
          ),
        ]),
      )),
    ]);
  }

  pw.Widget _buildTransactionTable(List<TransactionModel> transactions) {
    final sorted = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    final headers = ['Data', 'Descrição', 'Categoria', 'Tipo', 'Valor'];
    final rows = sorted.take(50).map((t) => [
      DateFormat('dd/MM/yy').format(t.date),
      t.title.length > 28 ? '${t.title.substring(0, 25)}...' : t.title,
      t.categoryName,
      t.type == TransactionType.income ? 'Receita' : 'Despesa',
      _fmt(t.amount),
    ]).toList();

    if (sorted.length > 50) {
      rows.add(['...', '${sorted.length - 50} transações omitidas', '', '', '']);
    }

    return _buildTable(headers, rows, columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(5),
      2: const pw.FlexColumnWidth(3),
      3: const pw.FlexColumnWidth(2),
      4: const pw.FlexColumnWidth(2.5),
    }, colorCell: (row, col) {
      if (col == 4 && row < sorted.length) {
        return sorted[row].type == TransactionType.income
            ? _incomeColor
            : _expenseColor;
      }
      return null;
    });
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Fluxo — Gestão Financeira Inteligente',
              style: pw.TextStyle(color: _textSecond, fontSize: 9)),
          pw.Text('Documento gerado automaticamente • Não possui validade fiscal',
              style: pw.TextStyle(color: _textSecond, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildTable(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? columnWidths,
    PdfColor? Function(int row, int col)? colorCell,
  }) {
    pw.TextStyle headerStyle() => pw.TextStyle(
          color: _primaryColor,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        );

    pw.TextStyle cellStyle(int row, int col) => pw.TextStyle(
          color: colorCell?.call(row, col) ?? _textPrimary,
          fontSize: 9,
        );

    return pw.Table(
      columnWidths: columnWidths,
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: _divider, width: 0.5),
        horizontalInside: pw.BorderSide(color: _divider, width: 0.5),
      ),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _surface),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 7, horizontal: 6),
                    child: pw.Text(h, style: headerStyle()),
                  ))
              .toList(),
        ),
        // Data rows
        ...rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;
          final isEven = rowIndex % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? _bgDark : _surface,
            ),
            children: row.asMap().entries
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 6, horizontal: 6),
                      child: pw.Text(
                        cell.value,
                        style: cellStyle(rowIndex, cell.key),
                      ),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(double value) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatter.format(value);
  }

  String _periodLabel(ReportPeriod p) => switch (p) {
        ReportPeriod.month1 => 'Último mês',
        ReportPeriod.month3 => 'Últimos 3 meses',
        ReportPeriod.month6 => 'Últimos 6 meses',
        ReportPeriod.month12 => 'Último ano',
      };
}