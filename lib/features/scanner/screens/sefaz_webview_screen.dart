import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/theme/app_theme.dart';
import '../services/sefaz_service.dart';

class SefazWebViewScreen extends ConsumerStatefulWidget {
  final String url;
  final String? accessKey;
  const SefazWebViewScreen({super.key, required this.url, this.accessKey});

  @override
  ConsumerState<SefazWebViewScreen> createState() => _SefazWebViewScreenState();
}

class _SefazWebViewScreenState extends ConsumerState<SefazWebViewScreen> {
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _noteDetected = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _isLoading = true;
          _noteDetected = false;
        }),
        onPageFinished: (url) async {
          setState(() => _isLoading = false);
          await Future.delayed(const Duration(milliseconds: 800));
          await _autofillAccessKey();
          await _checkIfNoteLoaded();
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<String> _getCleanHtml() async {
    // runJavaScriptReturningResult retorna o valor JS serializado como JSON.
    // Para strings JS, retorna: '"conteudo"' (com aspas externas).
    // jsonDecode remove as aspas e resolve todos os escapes de uma vez.
    final raw = await _webController.runJavaScriptReturningResult(
      'document.documentElement.outerHTML',
    ) as String;

    try {
      return jsonDecode(raw) as String;
    } catch (_) {
      // Fallback: strip outer quotes manualmente
      var html = raw;
      if (html.startsWith('"') && html.endsWith('"')) {
        html = html.substring(1, html.length - 1);
      }
      return html
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', '\t')
          .replaceAll(r'\"', '"')
          .replaceAll(r"\'", "'");
    }
  }

  Future<void> _autofillAccessKey() async {
    final key = widget.accessKey;
    if (key == null || key.isEmpty) return;

    // Formata a chave com espaços a cada 4 dígitos
    final formatted = key.replaceAllMapped(
      RegExp(r'.{4}'),
      (m) => '${m[0]} ',
    ).trim();

    // Injeta JS para preencher o campo de chave de acesso
    final js = """
      (function() {
        var input = document.querySelector('input[name="chNFe"]')
                 || document.querySelector('input[id="chNFe"]')
                 || document.querySelector('input[maxlength="54"]')
                 || document.querySelector('input[maxlength="44"]')
                 || document.querySelector('input[type="text"]');
        if (input) {
          input.value = '$formatted';
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
        }
      })();
    """;
    await _webController.runJavaScript(js);
  }

  Future<void> _checkIfNoteLoaded() async {
    try {
      final html = await _getCleanHtml();
      final doc = html_parser.parse(html);
      final bodyText = doc.body?.text ?? '';

      final hasTable    = doc.querySelector('table#tabResult') != null;
      final hasTxtTit   = doc.querySelector('.txtTit') != null;
      final hasProd     = doc.querySelector('#Prod') != null;
      final hasValorTotal = bodyText.contains('Valor total R\$') ||
          bodyText.contains('Valor a pagar') ||
          bodyText.contains('Vl. Total');
      final hasQtde     = bodyText.contains('Qtde') && bodyText.contains('Vl. Unit');
      final hasManyRows = doc.querySelectorAll('tr').length > 5;

      final isCaptchaPage = bodyText.contains('Não sou um robô') ||
          bodyText.contains('não sou um robô') ||
          (bodyText.contains('Consulta a Nota Fiscal') && !hasValorTotal);

      final noteLoaded = !isCaptchaPage &&
          (hasTable || hasTxtTit || hasProd || hasQtde || hasManyRows);

      if (noteLoaded && !_noteDetected) {
        setState(() => _noteDetected = true);
      }
    } catch (_) {}
  }

  Future<void> _importNote() async {
    setState(() => _importing = true);

    try {
      final html = await _getCleanHtml();
      final currentUrl = await _webController.currentUrl() ?? widget.url;

      // Debug: verifica se o HTML tem os elementos esperados
      final hasTabResult = html.contains('tabResult');
      final hasTxtTit = html.contains('txtTit');

      if (!hasTabResult && !hasTxtTit) {
        // HTML ainda não tem os itens — provavelmente ainda na página do captcha
        if (!mounted) return;
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'A nota ainda não carregou. Complete o reCAPTCHA e aguarde os itens aparecerem.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      final sefaz = SefazService();
      final receipt = await sefaz.parseHtml(html, currentUrl);

      if (!mounted) return;
      Navigator.of(context).pop(receipt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao importar: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Tentar novamente',
            textColor: Colors.white,
            onPressed: _importNote,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultar NF-e'),
        backgroundColor: AppColors.surfaceDark,
        actions: [
          if (_importing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
            )
          else ...[
            IconButton(
              onPressed: _checkIfNoteLoaded,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: 'Verificar se nota carregou',
            ),
            if (!_isLoading)
              TextButton.icon(
                onPressed: _importNote,
                icon: Icon(
                  Icons.download_rounded,
                  color: _noteDetected ? AppColors.accent : Colors.white54,
                ),
                label: Text(
                  'Importar',
                  style: TextStyle(
                    color: _noteDetected ? AppColors.accent : Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webController),

          if (_isLoading)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                color: AppColors.accent,
                backgroundColor: Colors.transparent,
              ),
            ),

          // Banner verde — nota detectada automaticamente
          if (_noteDetected && !_importing)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: const Color(0xFF00C896).withOpacity(0.96),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nota identificada! Toque em Importar.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _importNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text('IMPORTAR',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Instruções — nota ainda não detectada
          if (!_noteDetected && !_isLoading && !_importing)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: AppColors.surfaceDark.withOpacity(0.96),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nota visível? Use "Importar" no topo ou toque em Verificar.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _checkIfNoteLoaded();
                        if (!_noteDetected && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Use "Importar" no topo se a nota estiver visível.'),
                              action: SnackBarAction(
                                label: 'Importar agora',
                                onPressed: _importNote,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Verificar',
                          style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}