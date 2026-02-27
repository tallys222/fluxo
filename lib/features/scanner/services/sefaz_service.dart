import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/receipt_model.dart';

class SefazService {
  static const Duration _timeout = Duration(seconds: 15);

  Future<ReceiptModel> fetchReceipt(String qrUrl) async {
    _validateUrl(qrUrl);

    try {
      final response = await http
          .get(
            Uri.parse(qrUrl),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 Chrome/96.0 Mobile Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'pt-BR,pt;q=0.9',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw SefazException(
          'SEFAZ retornou status ${response.statusCode}. Tente novamente.',
        );
      }

      final document = html_parser.parse(response.body);
      return _parseDocument(document, qrUrl);
    } on SefazException {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        throw const SefazException(
          'Tempo limite excedido. Verifique sua conexão e tente novamente.',
        );
      }
      throw SefazException(
        'Não foi possível consultar a nota fiscal. ($msg)',
      );
    }
  }

  void _validateUrl(String url) {
    if (!url.startsWith('http')) {
      throw const SefazException('QR Code inválido. Esta não parece ser uma NFC-e.');
    }
    final knownDomains = [
      'nfce.sefaz.al.gov.br',
      'fazenda.sp.gov.br',
      'nfce.fazenda.sp.gov.br',
      'nfe.sefaz.rs.gov.br',
      'nfce.set.rn.gov.br',
      'nfc-e.sefaz.ce.gov.br',
      'nfce.sefaz.am.gov.br',
      'nfce.sefaz.mt.gov.br',
      'nfce.sefaz.ms.gov.br',
      'nfce.sefaz.go.gov.br',
      'nfce.sefa.pa.gov.br',
      'nfce.sefaz.rr.gov.br',
      'nfce.sefaz.ro.gov.br',
      'nfce.sefaz.ac.gov.br',
      'nfce.sefaz.ap.gov.br',
      'nfce.sefaz.ba.gov.br',
      'nfce.sefaz.es.gov.br',
      'nfce.sefaz.ma.gov.br',
      'nfce.sefaz.mg.gov.br',
      'nfce.sefaz.pb.gov.br',
      'nfce.sefaz.pe.gov.br',
      'nfce.sefaz.pi.gov.br',
      'nfce.sefaz.pr.gov.br',
      'nfce.sefaz.rj.gov.br',
      'nfce.sefaz.rn.gov.br',
      'nfce.sefaz.sc.gov.br',
      'nfce.sefaz.se.gov.br',
      'nfce.sefaz.to.gov.br',
      'df.sefaz.df.gov.br',
      'nfce.fazenda.df.gov.br',
    ];

    final uri = Uri.parse(url);
    final host = uri.host;
    // Aceita domínios da whitelist OU qualquer domínio .gov.br com sefaz/fazenda/nfe/nfce
    final isKnown = knownDomains.any((d) => host.contains(d)) ||
        (host.endsWith('.gov.br') &&
            (host.contains('sefaz') ||
             host.contains('fazenda') ||
             host.contains('nfe') ||
             host.contains('nfce')));
    if (!isKnown) {
      throw const SefazException(
        'Domínio não reconhecido como SEFAZ. Certifique-se de escanear uma NFC-e.',
      );
    }
  }

  /// Método público para parsear HTML já carregado (usado pelo WebView)
  ReceiptModel parseHtml(String htmlContent, String sourceUrl) {
    final doc = html_parser.parse(htmlContent);
    return _parseDocument(doc, sourceUrl);
  }

  ReceiptModel _parseDocument(Document doc, String qrUrl) {
    final uri = Uri.parse(qrUrl);

    final storeName = _extractText(doc, [
          '#u20', '.txtTopo', '.nfeEmit', 'span#u20',
          'div.txtTopo > p:first-child', 'h4.text-center',
        ]) ??
        _extractStoreNameFromLines(doc) ??
        _extractText(doc, ['title']) ??
        'Estabelecimento';

    final storeCnpj =
        _extractText(doc, ['#u21', '.txtTopo + p', 'span#u21']) ??
            _extractStoreCnpjFromLines(doc) ??
            '';

    final storeAddress =
        _extractText(doc, ['#u22', 'span#u22', '.enderecoEmitente']) ??
            _extractStoreAddressFromLines(doc) ??
            '';

    final accessKey = _extractAccessKey(doc);
    final issuedAt = _extractDate(doc);
    final items = _extractItems(doc, uri.host);
    final discount = _extractDiscount(doc);
    final total = _extractTotal(doc, items, discount);

    if (items.isEmpty) {
      throw const SefazException(
        'Não foi possível ler os itens da nota. '
        'O portal da SEFAZ pode estar temporariamente indisponível.',
      );
    }

    return ReceiptModel(
      id: '',
      qrUrl: qrUrl,
      storeName: _cleanText(storeName),
      storeCnpj: _cleanCnpj(storeCnpj),
      storeAddress: _cleanText(storeAddress),
      issuedAt: issuedAt,
      total: total,
      totalDiscount: discount,
      accessKey: accessKey,
      items: items,
    );
  }

  // ── Field extractors ──────────────────────────────────────────────────────

  String? _extractText(Document doc, List<String> selectors) {
    for (final selector in selectors) {
      try {
        final el = doc.querySelector(selector);
        if (el != null && el.text.trim().isNotEmpty) return el.text.trim();
      } catch (_) {}
    }
    return null;
  }

  String _extractAccessKey(Document doc) {
    final text = doc.body?.text ?? '';
    final match = RegExp(r'\d{44}').firstMatch(text);
    return match?.group(0) ?? '';
  }

  DateTime _extractDate(Document doc) {
    for (final sel in ['#u24', '#dhEmi', 'span#u24', '.dhEmi']) {
      final el = doc.querySelector(sel);
      if (el == null) continue;
      final m = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(el.text.trim());
      if (m != null) {
        return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!),
            int.parse(m.group(1)!));
      }
    }
    final raw = _normalizedBodyText(doc);
    final m = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(raw);
    if (m != null) {
      return DateTime(
          int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    }
    return DateTime.now();
  }

  double _extractTotal(Document doc, List<ReceiptItem> items, double discount) {
    // Formato WebView: label "Valor a pagar R$" → span.totalNumb.txtMax
    final linhas = doc.querySelectorAll('#totalNota #linhaTotal');
    for (final linha in linhas) {
      final label = linha.querySelector('label')?.text ?? '';
      if (label.contains('Valor a pagar') || label.contains('a pagar')) {
        final span = linha.querySelector('.totalNumb');
        if (span != null) {
          final v = _parseCurrency(span.text);
          if (v > 0) return v;
        }
      }
    }
    // Formato WebView: fallback para "Valor total R$" - desconto
    for (final linha in linhas) {
      final label = linha.querySelector('label')?.text ?? '';
      if (label.contains('Valor total')) {
        final span = linha.querySelector('.totalNumb');
        if (span != null) {
          final v = _parseCurrency(span.text);
          if (v > 0) return discount > 0 ? v - discount : v;
        }
      }
    }

    for (final sel in [
      '#u42', '#vNF', 'span#u42', '#totalNota', '.totalNota', '#vTotalNota',
    ]) {
      final el = doc.querySelector(sel);
      if (el == null || el.text.trim().isEmpty) continue;
      final v = _parseCurrency(el.text);
      if (v > 0) return v;
    }

    final raw = _normalizedBodyText(doc);

    double lastMatch(RegExp re) {
      double last = 0.0;
      for (final m in re.allMatches(raw)) {
        final v = _parseCurrency(m.group(1) ?? '0');
        if (v > 0) last = v;
      }
      return last;
    }

    // Prioridade: "Valor a pagar" (já com desconto) > "Valor total" (bruto)
    final vPagar = lastMatch(
        RegExp(r'Valor\s*a\s*pagar\s*(?:R\$\s*:?\s*|R\$\s*)?([\d\.,]+)',
            caseSensitive: false));
    if (vPagar > 0) return vPagar;

    // Fallback: "Valor total" - desconto (se houver)
    final vTotal = lastMatch(
        RegExp(r'Valor\s+total\s+(?:R\$\s*:?\s*|R\$\s*)?([\d\.,]+)',
            caseSensitive: false));
    if (vTotal > 0) return discount > 0 ? vTotal - discount : vTotal;

    if (items.isNotEmpty) {
      return items.fold<double>(0.0, (acc, it) => acc + it.totalPrice);
    }

    return 0.0;
  }

  double _extractDiscount(Document doc) {
    // Formato WebView
    final linhas = doc.querySelectorAll('#totalNota #linhaTotal');
    for (final linha in linhas) {
      final label = linha.querySelector('label')?.text ?? '';
      if (label.contains('Desconto') || label.contains('desconto')) {
        final span = linha.querySelector('.totalNumb');
        if (span != null) {
          final v = _parseCurrency(span.text);
          if (v > 0) return v;
        }
      }
    }
    for (final sel in ['#u43', '#vDesc', 'span#u43']) {
      final el = doc.querySelector(sel);
      if (el == null || el.text.trim().isEmpty) continue;
      final v = _parseCurrency(el.text);
      if (v > 0) return v;
    }
    final raw = _normalizedBodyText(doc);
    double last = 0.0;
    for (final m in RegExp(r'Descontos?\s*R?\$\s*([\d\.,]+)',
        caseSensitive: false).allMatches(raw)) {
      final v = _parseCurrency(m.group(1) ?? '0');
      if (v > 0) last = v;
    }
    return last;
  }

  List<ReceiptItem> _extractItems(Document doc, String host) {
    // Strategy 0: formato WebView (tabela com spans .txtTit/.Rqtd/.RUN/.RvlUnit/.valor)
    // Este é o formato retornado pelo portal consultaNFCe.htm após reCAPTCHA
    final bySpans = _extractItemsBySpans(doc);
    if (bySpans.isNotEmpty) return bySpans;

    // AL: tenta parser por linhas primeiro
    if (host.contains('nfce.sefaz.al.gov.br')) {
      final al = _extractItemsAlByLines(doc);
      if (al.isNotEmpty) return al;
    }

    final items = <ReceiptItem>[];

    // Strategy 1: tabela
    final rows = doc.querySelectorAll('table#tabResult tr, table.table tr');
    if (rows.isNotEmpty) {
      for (final row in rows.skip(1)) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 4) continue;

        final name = _cleanText(cells[0].text);
        if (name.isEmpty) continue;
        if (name.toLowerCase() == 'descrição') continue;
        // ── FILTRO: pula linhas de emitente/CNPJ ──
        if (_isEmitenteLine(name)) continue;

        final qty = _parseDouble(cells[1].text);
        final unit = cells.length > 2 ? cells[2].text.trim() : 'UN';
        final unitPrice = _parseCurrency(cells.length > 3 ? cells[3].text : '0');
        final total = _parseCurrency(cells.length > 4 ? cells[4].text : '0');
        final effectiveQty = qty == 0 ? 1.0 : qty;

        // Fix KG: quando sem coluna de total e unit é peso/volume,
        // totalPrice correto = unitPrice × qty
        double realTotal = total > 0 ? total : unitPrice * effectiveQty;
        final isWeight = ['KG', 'G', 'L', 'ML', 'MT'].contains(unit.trim().toUpperCase());
        if (total <= 0 && isWeight && unitPrice > 0) {
          realTotal = unitPrice * effectiveQty;
        }

        items.add(ReceiptItem(
          name: name,
          quantity: effectiveQty,
          unit: unit.isEmpty ? 'UN' : unit,
          unitPrice: unitPrice,
          totalPrice: realTotal,
        ));
      }
    }

    // Strategy 2: divs
    if (items.isEmpty) {
      final itemDivs = doc.querySelectorAll(
          'div#Prod, div.item, li.item, div[id^="Item"]');
      for (final div in itemDivs) {
        final nameEl = div.querySelector(
            'span.txtTit, .nomeProduto, span[id*="xProd"]');
        if (nameEl == null) continue;
        final name = _cleanText(nameEl.text);
        if (name.isEmpty || _isEmitenteLine(name)) continue;

        final qtyEl = div.querySelector('span.Rqtd, .quantidade, span[id*="qCom"]');
        final unitPriceEl =
            div.querySelector('span.RvlUnit, .valorUnitario, span[id*="vUnCom"]');
        final totalEl =
            div.querySelector('span.valor, .valorTotal, span[id*="vProd"]');

        final qty = qtyEl != null ? _parseDouble(qtyEl.text) : 1.0;
        final unitPrice =
            unitPriceEl != null ? _parseCurrency(unitPriceEl.text) : 0.0;
        final total = totalEl != null ? _parseCurrency(totalEl.text) : 0.0;
        final effectiveQty = qty == 0 ? 1.0 : qty;

        items.add(ReceiptItem(
          name: name,
          quantity: effectiveQty,
          unit: 'UN',
          unitPrice: unitPrice,
          totalPrice: total > 0 ? total : unitPrice * effectiveQty,
        ));
      }
    }

    // Estratégia 3: texto plano com padrão "Qtde.:"
    if (items.isEmpty) {
      items.addAll(_extractByQtdePattern(_normalizedBodyText(doc)));
    }

    _cleanupItems(items);
    return items;
  }

  // ── AL: parser por linhas ─────────────────────────────────────────────────

  List<String> _bodyLines(Document doc) {
    final rawOriginal = (doc.body?.text ?? '').replaceAll('\u00A0', ' ');
    final initial = rawOriginal
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (initial.length <= 2) {
      // HTML veio "achatado" — reinsere quebras antes de marcadores conhecidos
      var raw = rawOriginal.replaceAll(RegExp(r'\s+'), ' ').trim();
      for (final pattern in [
        RegExp(r'\bCNPJ\s*:', caseSensitive: false),
        RegExp(r'\bQtde\.?:?', caseSensitive: false),
        RegExp(r'\bValor\s+total\b', caseSensitive: false),
        RegExp(r'\bValor\s+a\s+pagar\b', caseSensitive: false),
        RegExp(r'\bDescontos?\b', caseSensitive: false),
        RegExp(r'\bDocumento\s+Auxiliar\b', caseSensitive: false),
      ]) {
        raw = raw.replaceAllMapped(pattern, (m) => '\n${m[0]}');
      }
      raw = raw.replaceAllMapped(
        RegExp(r'(?=(\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}))'), (_) => '\n');
      raw = raw.replaceAllMapped(
        RegExp(r'(?<=Vl\.\s*Total)\s*', caseSensitive: false), (_) => '\n');

      return raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    return initial;
  }

  String? _extractStoreNameFromLines(Document doc) {
    final lines = _bodyLines(doc);
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains('documento auxiliar') &&
          i + 1 < lines.length) {
        return lines[i + 1].trim();
      }
    }
    for (final l in lines) {
      final ll = l.toLowerCase();
      if (ll.contains('ltda') || ll.contains('eireli') || ll.contains(' me')) {
        return l.trim();
      }
    }
    return null;
  }

  String? _extractStoreCnpjFromLines(Document doc) {
    final lines = _bodyLines(doc);
    for (final l in lines) {
      final m = RegExp(r'CNPJ\s*:\s*([\d\.\-/]+)', caseSensitive: false)
          .firstMatch(l);
      if (m != null) return m.group(1)?.trim();
    }
    for (final l in lines) {
      final m = RegExp(r'(\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})').firstMatch(l);
      if (m != null) return m.group(1)?.trim();
    }
    return null;
  }

  String? _extractStoreAddressFromLines(Document doc) {
    final lines = _bodyLines(doc);
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toUpperCase().startsWith('CNPJ') && i + 1 < lines.length) {
        final addr = lines[i + 1].trim();
        if (!addr.contains('(Código:') && addr.length >= 8) return addr;
      }
    }
    return null;
  }

  /// Parser para o formato do portal consultaNFCe.htm (usado via WebView após reCAPTCHA).
  /// Cada <tr> tem 2 <td>:
  ///   td[0]: .txtTit (nome) + .Rqtd (qty) + .RUN (unidade) + .RvlUnit (preço unit.)
  ///   td[1]: .valor (total)
  List<ReceiptItem> _extractItemsBySpans(Document doc) {
    final rows = doc.querySelectorAll('table#tabResult tr');
    if (rows.isEmpty) return [];

    final items = <ReceiptItem>[];

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 2) continue;

      final td0 = cells[0];
      final td1 = cells[1];

      final nameEl = td0.querySelector('.txtTit');
      if (nameEl == null) continue;
      final name = _cleanText(nameEl.text);
      if (name.isEmpty) continue;

      // Quantidade: span.Rqtd → "Qtde.:1" ou "Qtde.:0,205"
      final qtyEl = td0.querySelector('.Rqtd');
      final qtyText = qtyEl?.text ?? '1';
      final qty = _parseDouble(qtyText.replaceAll(RegExp(r'[Qq]tde\.?:?\s*'), ''));

      // Unidade: span.RUN → "UN: Kg" ou "UN: Un"
      final unitEl = td0.querySelector('.RUN');
      final unitText = unitEl?.text ?? 'UN';
      final unit = unitText.replaceAll(RegExp(r'UN:\s*', caseSensitive: false), '').trim();

      // Preço unitário: span.RvlUnit → "Vl. Unit.: 26,49"
      final unitPriceEl = td0.querySelector('.RvlUnit');
      final unitPriceText = unitPriceEl?.text ?? '0';
      final unitPrice = _parseCurrency(unitPriceText);

      // Total: span.valor na segunda célula
      final totalEl = td1.querySelector('.valor, span.valor');
      final totalText = totalEl?.text ?? '';
      final total = totalText.isNotEmpty
          ? _parseCurrency(totalText)
          : unitPrice * (qty == 0 ? 1.0 : qty);

      final effectiveQty = qty == 0 ? 1.0 : qty;
      final effectiveUnitPrice = unitPrice == 0 && total > 0
          ? total / effectiveQty
          : unitPrice;

      items.add(ReceiptItem(
        name: name,
        quantity: effectiveQty,
        unit: unit.isEmpty ? 'UN' : unit,
        unitPrice: effectiveUnitPrice,
        totalPrice: total > 0 ? total : effectiveUnitPrice * effectiveQty,
      ));
    }

    return items;
  }

  List<ReceiptItem> _extractItemsAlByLines(Document doc) {
    final lines = _bodyLines(doc);
    if (lines.isEmpty) return const [];

    final items = <ReceiptItem>[];

    final reQtyLine = RegExp(
      r'Qtde\.?:?\s*([\d\.,]+)\s*UN:\s*([A-Za-z]+)\s*Vl\.\s*Unit\.?:?\s*([\d\.,]+)',
      caseSensitive: false,
    );

    bool looksLikeProductName(String s) {
      final t = _cleanText(s);
      if (t.length < 3) return false;
      if (_isEmitenteLine(t)) return false;
      if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(t)) return false;
      if (RegExp(r'^[\d\.,]+$').hasMatch(t)) return false;
      return true;
    }

    String findBestName(int idxQtyLine) {
      for (var back = 1; back <= 4; back++) {
        final j = idxQtyLine - back;
        if (j < 0) break;
        final cand = lines[j].trim();
        // Pula linha de código "(Código: XXXX)" e vai para o nome real
        if (RegExp(r'^\(Código', caseSensitive: false).hasMatch(cand)) continue;
        if (looksLikeProductName(cand)) return _cleanText(cand);
      }
      // Fallback: retorna a linha anterior após strip do código
      final j = idxQtyLine - 1;
      if (j >= 0) {
        final raw = lines[j].trim();
        // Remove o sufixo de código se vier junto
        final cleaned = _cleanText(raw);
        if (cleaned.isNotEmpty) return cleaned;
      }
      return 'Item';
    }

    for (var i = 0; i < lines.length; i++) {
      final qtyMatch = reQtyLine.firstMatch(lines[i]);
      if (qtyMatch == null) continue;

      final name = findBestName(i);
      if (_isEmitenteLine(name)) continue;

      final qty = _parseDouble(qtyMatch.group(1) ?? '1');
      final unit = (qtyMatch.group(2) ?? 'UN').trim();
      final unitPrice = _parseCurrency(qtyMatch.group(3) ?? '0');

      double total = 0.0;
      final inlineTotal = RegExp(
        r'Vl\.\s*Total\s*([\d\.,]+)',
        caseSensitive: false,
      ).firstMatch(lines[i]);
      if (inlineTotal != null) total = _parseCurrency(inlineTotal.group(1) ?? '0');

      final effectiveQty = qty == 0 ? 1.0 : qty;

      // SEFAZ AL quebra a linha após "Vl. Unit.:" para TODOS os itens:
      //   linha i   → "Qtde.: 2 UN: UN Vl. Unit.:"        → unitPrice = 0
      //   linha i+1 → "6,79"                               → preço unitário real
      //   linha i+2 → "Vl. Total: 13,58" ou "13,58"        → total real
      //
      // Quando unitPrice==0, buscamos nas próximas linhas:
      //   i+1 = unitPrice real
      //   i+2 = total real (prioriza "Vl. Total", fallback = número puro)

      double realUnitPrice = unitPrice;
      double realTotal     = total; // total inline já capturado (se houver)

      if (unitPrice == 0) {
        // Linha i+1 → preço unitário
        if (i + 1 < lines.length) {
          final l1 = lines[i + 1].trim();
          final v1 = _parseCurrency(l1);
          if (v1 > 0 && !_isEmitenteLine(l1)) {
            realUnitPrice = v1;
          }
        }
        // Linha i+2 → total real (Vl. Total ou número puro)
        if (i + 2 < lines.length) {
          final l2 = lines[i + 2].trim();
          final vlTotalMatch = RegExp(
            r'Vl\.\s*Total\s*([\d\.,]+)',
            caseSensitive: false,
          ).firstMatch(l2);
          if (vlTotalMatch != null) {
            realTotal = _parseCurrency(vlTotalMatch.group(1) ?? '0');
          } else {
            final v2 = _parseCurrency(l2);
            if (v2 > 0 && !_isEmitenteLine(l2)) realTotal = v2;
          }
        }
      } else if (total <= 0) {
        // unitPrice foi capturado inline, mas sem total → busca nas próximas linhas
        if (i + 1 < lines.length) {
          final l1 = lines[i + 1].trim();
          final vlTotalMatch = RegExp(
            r'Vl\.\s*Total\s*([\d\.,]+)',
            caseSensitive: false,
          ).firstMatch(l1);
          if (vlTotalMatch != null) {
            realTotal = _parseCurrency(vlTotalMatch.group(1) ?? '0');
          } else {
            final v1 = _parseCurrency(l1);
            if (v1 > 0 && !_isEmitenteLine(l1)) realTotal = v1;
          }
        }
      }

      // Fallback: se ainda sem total, calcula pelo preço unitário × qty
      if (realTotal <= 0 && realUnitPrice > 0) {
        realTotal = realUnitPrice * effectiveQty;
      }

      items.add(ReceiptItem(
        name: name,
        quantity: effectiveQty,
        unit: unit.isEmpty ? 'UN' : unit,
        unitPrice: realUnitPrice,
        totalPrice: realTotal,
      ));
    }

    _cleanupItems(items);
    return items;
  }

  // ── Estratégia 3: padrão Qtde. no texto plano ─────────────────────────────

  List<ReceiptItem> _extractByQtdePattern(String raw) {
    final items = <ReceiptItem>[];
    final re = RegExp(
      r'([A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9\s\-\./,]{2,}?)\s*'
      r'(?:\(Código:.*?\))?\s*'
      r'Qtde\.?:?\s*([\d\.,]+)\s*UN:\s*([A-Za-z]+)\s*'
      r'Vl\.\s*Unit\.?:?\s*([\d\.,]+)\s*'
      r'Vl\.\s*Total\s*([\d\.,]+)',
      caseSensitive: false,
    );

    for (final m in re.allMatches(raw)) {
      final name = _cleanText(m.group(1) ?? '');
      if (name.isEmpty || _isEmitenteLine(name)) continue;

      final qty = _parseDouble(m.group(2) ?? '1');
      final unit = (m.group(3) ?? 'UN').trim();
      final unitPrice = _parseCurrency(m.group(4) ?? '0');
      final total = _parseCurrency(m.group(5) ?? '0');
      final effectiveQty = qty == 0 ? 1.0 : qty;

      items.add(ReceiptItem(
        name: name,
        quantity: effectiveQty,
        unit: unit.isEmpty ? 'UN' : unit,
        unitPrice: unitPrice,
        totalPrice: total > 0 ? total : unitPrice * effectiveQty,
      ));
    }
    return items;
  }

  // ── Filtro de linhas de emitente ──────────────────────────────────────────
  // Centralizado aqui para ser usado em TODAS as estratégias

  bool _isEmitenteLine(String s) {
    final t = s.trim();
    if (t.isEmpty) return true;

    // CNPJ formatado (ex: 15.353.706/0001-04)
    if (RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}').hasMatch(t)) return true;
    if (t.toLowerCase().contains('cnpj')) return true;

    final low = t.toLowerCase();
    if (low.contains('inscr') && low.contains('estad')) return true;
    if (low.contains('documento auxiliar')) return true;
    if (low.contains('secretaria') || low.contains('fazenda')) return true;
    if (low.contains('gerência') || low.contains('cadastro')) return true;
    if (low.startsWith('valor total') ||
        low.startsWith('valor a pagar') ||
        low.startsWith('desconto') ||
        low.startsWith('javascript') ||
        low.contains('este aplicativo') ||
        low.contains('para funcionar corretamente') ||
        low.contains('nota fiscal de consumidor')) return true;

    // Linha de código de produto: "(Código: XXXX)" — não é nome de produto
    if (RegExp(r'^\(Código', caseSensitive: false).hasMatch(t)) return true;
    // Linha só de código numérico
    if (RegExp(r'^\(?\d{4,}\)?$').hasMatch(t)) return true;

    // Endereço (começa com logradouro)
    if (RegExp(r'^(av|avenida|rua|travessa|rodovia|estrada)\b',
            caseSensitive: false)
        .hasMatch(t)) return true;

    return false;
  }

  void _cleanupItems(List<ReceiptItem> items) {
    items.removeWhere((it) => _isEmitenteLine(it.name));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalizedBodyText(Document doc) {
    return (doc.body?.text ?? '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _parseCurrency(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[^\d,\.]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  double _parseDouble(String text) {
    final cleaned =
        text.replaceAll(RegExp(r'[^\d,\.]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _cleanText(String text) => text
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'[\u0000-\u001F]'), ' ')
      // Remove sufixo "(Código: XXXX )" que a SEFAZ AL adiciona ao nome
      .replaceAll(RegExp(r'\s*\(Código:\s*\d+\s*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _cleanCnpj(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 14) {
      return '${digits.substring(0, 2)}.${digits.substring(2, 5)}'
          '.${digits.substring(5, 8)}/${digits.substring(8, 12)}'
          '-${digits.substring(12)}';
    }
    return text.trim();
  }
}

class SefazException implements Exception {
  final String message;
  const SefazException(this.message);

  @override
  String toString() => message;
}

final sefazServiceProvider = Provider<SefazService>((ref) => SefazService());