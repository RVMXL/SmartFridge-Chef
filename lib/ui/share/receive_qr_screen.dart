/// Экран «Принять продукты» (v0.5.0): непрерывное сканирование QR-серии
/// от второго телефона. Страницы собираются по номеру, дубликаты
/// игнорируются (камера видит один и тот же код много раз — это норма).
/// Когда собраны все — предложение добавить продукты в холодильник.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../share/product_share_codec.dart';
import '../../state/product_controller.dart';

class ReceiveQrScreen extends StatefulWidget {
  const ReceiveQrScreen({super.key});

  @override
  State<ReceiveQrScreen> createState() => _ReceiveQrScreenState();
}

class _ReceiveQrScreenState extends State<ReceiveQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// Принятые страницы: номер → байты куска payload.
  final Map<int, List<int>> _chunks = {};

  /// Всего страниц (фиксируется первой распознанной).
  int? _total;

  /// Передача уже собирается (защита от повторного запуска).
  bool _importing = false;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_importing || _done || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      final chunk = ProductShareCodec.tryParseChunk(value);
      if (chunk == null) continue; // чужой QR — молча пропускаем

      // Разные передачи подряд: если общее число страниц не совпало
      // и текущая передача ещё не собрана — начинаем заново.
      if (_total != null && chunk.total != _total) {
        if (_chunks.length < _total!) {
          _chunks.clear();
          _total = chunk.total;
        } else {
          continue;
        }
      }
      _total ??= chunk.total;

      if (_chunks.containsKey(chunk.id)) continue; // дубликат страницы
      _chunks[chunk.id] = chunk.bodyBytes;
      HapticFeedback.selectionClick();
      if (mounted) setState(() {});

      final payload = ProductShareCodec.assemble(_chunks, _total!);
      if (payload != null) {
        _importing = true;
        _finishScan(payload);
      }
      return;
    }
  }

  Future<void> _finishScan(String payload) async {
    final l = AppLocalizations.of(context);
    final controller = context.read<ProductController>();
    List<Product> incoming;
    try {
      incoming = ProductShareCodec.decodePayload(payload).products;
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _chunks.clear();
        _total = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.receiveQrBroken)),
      );
      return;
    }
    if (incoming.isEmpty) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _chunks.clear();
        _total = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.receiveQrEmpty)),
      );
      return;
    }

    // Подтверждение: что добавляем.
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(l.receiveQrConfirmTitle(incoming.length)),
        content: Text(l.receiveQrConfirmBody(
          incoming.length > 5 ? incoming.length - 5 : 0,
          incoming.take(5).map((p) => p.name).join(', '),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: Text(l.commonAdd),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      setState(() {
        _importing = false;
        _chunks.clear();
        _total = null;
      });
      return;
    }

    // Дубликаты по штрих-коду считаем честно: addAll пропускает занятые
    // коды (частично-уникальный индекс), это не ошибка.
    final saved = await controller.addAll(incoming);
    final skipped = incoming.length - saved;
    if (!mounted) return;
    _done = true;
    await _controller.stop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.receiveQrDone(saved, skipped))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = _total;
    final received = _chunks.length;

    return Scaffold(
      appBar: AppBar(title: Text(l.receiveQrTitle)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _Hint(
              icon: Icons.no_photography_outlined,
              text: l.scanCameraError,
            ),
          ),
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: _Hint(
                icon: Icons.qr_code_scanner,
                text: total == null
                    ? l.receiveQrWaiting
                    : l.receiveQrProgress(received, total),
                showProgress: total != null,
                progress: total == null || total == 0
                    ? 0
                    : received / total,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.icon,
    required this.text,
    this.showProgress = false,
    this.progress = 0,
  });

  final IconData icon;
  final String text;
  final bool showProgress;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: progress.clamp(0, 1)),
            ),
          ],
        ],
      ),
    );
  }
}
