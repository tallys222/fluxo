import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/scanner_provider.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/repositories/transaction_repository.dart';
import '../services/bill_parser_service.dart';
import 'sefaz_webview_screen.dart';
import 'receipt_review_sheet.dart';
import 'bill_review_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _torchOn = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.stop();
      _isActive = false;
    } else if (state == AppLifecycleState.resumed && _hasPermission) {
      _controller?.start();
      _isActive = true;
    }
  }

  OverlayEntry? _loadingOverlay;

  void _showLoadingOverlay() {
    _loadingOverlay = OverlayEntry(
      builder: (_) => Container(
        color: Colors.black54,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  SizedBox(height: 16),
                  Text('Analisando fatura com IA…', textAlign: TextAlign.center),
                  SizedBox(height: 4),
                  Text(
                    'Isso pode levar até 1 minuto',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  Future<void> _openBillImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    _showLoadingOverlay();

    BillParseResult parseResult;
    try {
      parseResult = await BillParserService().parsePdf(File(path));
    } catch (e) {
      _hideLoadingOverlay();
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
      return;
    }

    _hideLoadingOverlay();
    if (!mounted) return;

    if (parseResult.transactions.isEmpty) {
      _showError('Nenhuma transação encontrada na fatura.');
      return;
    }

    final selected = await Navigator.of(context, rootNavigator: false).push<List<BillTransaction>>(
      MaterialPageRoute(
        builder: (_) => BillReviewScreen(parseResult: parseResult),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    await _importTransactions(selected);
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Erro ao importar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _importTransactions(List<BillTransaction> items) async {
    final repo = TransactionRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    const uuid = Uuid();
    int count = 0;

    for (final item in items) {
      try {
        final tx = TransactionModel(
          id: uuid.v4(),
          title: item.description,
          amount: item.amount,
          type: item.isCredit ? TransactionType.income : TransactionType.expense,
          categoryId: item.isCredit ? 'outros' : item.categoryId,
          categoryName: item.isCredit ? 'Estorno' : item.categoryName,
          categoryIcon: item.isCredit ? '↩' : item.categoryIcon,
          categoryColor: item.isCredit ? '#4CAF50' : item.categoryColor,
          date: item.toDateTime(),
          note: item.cardLast4 != null ? 'Cartão ••${item.cardLast4}' : null,
        );
        await repo.addTransaction(tx);
        count++;
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count lançamento${count == 1 ? '' : 's'} importado${count == 1 ? '' : 's'}!'),
          backgroundColor: const Color(0xFFD4AF37),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkPermission() async {    final status = await Permission.camera.request();
    setState(() => _hasPermission = status.isGranted);
    if (_hasPermission) _initCamera();
  }

  void _initCamera() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isActive) return;

    for (final barcode in capture.barcodes) {
      final url = barcode.rawValue;
      if (url == null || url.isEmpty) continue;
      if (!url.startsWith('http')) continue;

      // Pause scanner while processing
      _controller?.stop();
      setState(() => _isActive = false);

      ref.read(scannerProvider.notifier).processQrCode(url);
      break;
    }
  }

  void _resumeScanner() {
    ref.read(scannerProvider.notifier).clearError();
    _controller?.start();
    setState(() => _isActive = true);
  }

  Future<void> _showKeyDialog() async {
    _controller?.stop();
    setState(() => _isActive = false);

    String? submittedKey;
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Inserir chave de acesso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use quando o QR Code da nota estiver com URL inválida.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Chave de acesso (44 dígitos)',
                hintText: '2726 0215 3537...',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              submittedKey = ctrl.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('Consultar'),
          ),
        ],
      ),
    );

    // Cancelou ou não digitou nada
    if (submittedKey == null || submittedKey!.isEmpty) {
      _resumeScanner();
      return;
    }

    // Abre diretamente o WebView com a página de consulta por chave
    // (que tem reCAPTCHA) — sem tentar consulta direta que sempre falha
    await _openWebViewFallback(submittedKey!);
  }

  Future<void> _openWebViewFallback(String rawKey) async {
    final key = rawKey.replaceAll(RegExp(r'[\s\-\.]+'), '');
    if (key.length != 44) return;

    // URL da página de consulta por chave (com reCAPTCHA)
    final stateCode = key.substring(0, 2);
    final webUrl = _captchaUrlFromKey(stateCode, key);
    if (webUrl == null) return;

    ref.read(scannerProvider.notifier).clearError();

    final receipt = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SefazWebViewScreen(url: webUrl, accessKey: key),
      ),
    );

    if (receipt != null) {
      // Importa o recibo retornado pelo WebView
      ref.read(scannerProvider.notifier).setReceiptFromWebView(receipt);
    } else {
      _resumeScanner();
    }
  }

  String? _captchaUrlFromKey(String uf, String key) {
    return switch (uf) {
      '27' => 'https://nfce.sefaz.al.gov.br/consultaNFCe.htm',
      '35' => 'https://www.nfce.fazenda.sp.gov.br/consulta',
      '33' => 'https://nfce.fazenda.rj.gov.br/consulta',
      '31' => 'https://nfce.fazenda.mg.gov.br/consulta',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerProvider);

    // Open review sheet when receipt is ready
    ref.listen(scannerProvider, (prev, next) {
      if (next.status == ScanStatus.success && next.receipt != null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ReceiptReviewSheet(receipt: next.receipt!),
        ).then((_) => _resumeScanner());
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear NF-e',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Importar fatura de cartão
          IconButton(
            icon: const Icon(Icons.credit_card_outlined, color: Colors.white),
            tooltip: 'Importar fatura do cartão',
            onPressed: _openBillImport,
          ),
          if (_hasPermission && _controller != null)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off_outlined,
                color: _torchOn ? AppColors.accent : Colors.white,
              ),
              onPressed: () async {
                await _controller?.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
        ],
      ),
      body: !_hasPermission
          ? _PermissionDeniedView(onRequest: _checkPermission)
          : Stack(
              children: [
                // Camera
                if (_controller != null)
                  MobileScanner(
                    controller: _controller!,
                    onDetect: _onDetect,
                  ),

                // Overlay
                _ScannerOverlay(),

                // Status overlay
                if (scanState.status == ScanStatus.loading)
                  _LoadingOverlay(),

                if (scanState.status == ScanStatus.error)
                  _ErrorOverlay(
                    message: scanState.errorMessage ?? 'Erro desconhecido',
                    onRetry: _resumeScanner,
                  ),

                // Instructions + manual key button
                if (scanState.status == ScanStatus.idle)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _BottomInstructions(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          child: TextButton.icon(
                            onPressed: _showKeyDialog,
                            icon: const Icon(Icons.keyboard_alt_outlined,
                                color: Colors.white70, size: 18),
                            label: const Text(
                              'QR Code inválido? Inserir chave manualmente',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Scanner Overlay (frame + corners) ────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width * 0.68;

    // Posiciona o frame no terço superior da tela, deixando espaço
    // suficiente abaixo para o texto de instrução e botão de chave manual.
    // ~22% do alto = label acima do frame, ~45% = frame, ~33% = instruções
    final top = size.height * 0.12;

    return Stack(
      children: [
        // Dark overlay
        CustomPaint(
          size: size,
          painter: _OverlayPainter(
            frameSize: frameSize,
            top: top,
          ),
        ),

        // Corner decorations
        Positioned(
          top: top,
          left: (size.width - frameSize) / 2,
          child: _CornerFrame(size: frameSize),
        ),

        // Scan label
        Positioned(
          top: top - 44,
          left: 0,
          right: 0,
          child: const Center(
            child: Text(
              'Aponte para o QR Code da NF-e',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double frameSize;
  final double top;

  _OverlayPainter({required this.frameSize, required this.top});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);
    final left = (size.width - frameSize) / 2;

    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), paint);
    // Bottom
    canvas.drawRect(
        Rect.fromLTWH(0, top + frameSize, size.width, size.height), paint);
    // Left
    canvas.drawRect(Rect.fromLTWH(0, top, left, frameSize), paint);
    // Right
    canvas.drawRect(
        Rect.fromLTWH(left + frameSize, top, size.width, frameSize), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerFrame extends StatelessWidget {
  final double size;
  const _CornerFrame({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        _corner(0, 0, [BorderSide.none, BorderSide.none]),
        Positioned(
          top: 0,
          left: 0,
          child: _CornerPiece(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8)),
            top: true,
            left: true,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _CornerPiece(
            borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8)),
            top: true,
            left: false,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: _CornerPiece(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8)),
            top: false,
            left: true,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _CornerPiece(
            borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(8)),
            top: false,
            left: false,
          ),
        ),
      ]),
    );
  }

  Widget _corner(double t, double l, List<BorderSide> s) =>
      const SizedBox.shrink();
}

class _CornerPiece extends StatelessWidget {
  final BorderRadius borderRadius;
  final bool top;
  final bool left;

  const _CornerPiece({
    required this.borderRadius,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border(
          top: top
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}

// ── Loading Overlay ───────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            Gap(20),
            Text(
              'Consultando SEFAZ...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Gap(8),
            Text(
              'Aguarde alguns segundos',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Overlay ─────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorOverlay({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
            ),
            const Gap(20),
            const Text(
              'Não foi possível ler a nota',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Instructions ───────────────────────────────────────────────────

class _BottomInstructions extends StatelessWidget {
  const _BottomInstructions();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white60, size: 18),
          Gap(10),
          Expanded(
            child: Text(
              'Escaneie o QR Code impresso no cupom fiscal da sua compra. '
              'Os dados serão consultados diretamente no portal da SEFAZ.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Permission Denied ─────────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRequest;
  const _PermissionDeniedView({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 72, color: Colors.white54),
            const Gap(20),
            const Text(
              'Permissão de câmera necessária',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            const Text(
              'Para escanear QR codes de notas fiscais, '
              'o Fluxo precisa acessar sua câmera.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            ElevatedButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Permitir câmera'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent),
            ),
            const Gap(12),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Abrir configurações',
                  style: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
      ),
    );
  }
}