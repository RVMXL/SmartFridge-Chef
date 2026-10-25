/// Экран «Показать QR» (v0.5.0): серия QR-кодов со всеми активными
/// продуктами холодильника для передачи второму телефону.
///
/// Одиночная передача (мало продуктов) — один код; много продуктов —
/// страницы формата Amnezia (850 байт/страницу, до 255 страниц).
/// Автопрокрутка включена по умолчанию: держи экран напротив камеры
/// получателя, страницы сменяются сами; кнопками можно листать вручную.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/models/product.dart';
import '../../share/product_share_codec.dart';
import '../../state/product_controller.dart';

class ShareQrScreen extends StatefulWidget {
  const ShareQrScreen({super.key});

  @override
  State<ShareQrScreen> createState() => _ShareQrScreenState();
}

class _ShareQrScreenState extends State<ShareQrScreen> {
  List<String> _pages = const [];
  bool _auto = true;
  int _index = 0;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildPages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _buildPages() async {
    final controller = context.read<ProductController>();
    await controller.refresh();
    if (!mounted) return;
    final products = controller.products
        .where((p) => p.status == ProductStatus.active)
        .toList();
    if (products.isEmpty) {
      setState(() => _pages = const []);
      return;
    }
    try {
      final pages = ProductShareCodec.encode(products);
      setState(() {
        _pages = pages;
        _index = 0;
        _failed = false;
      });
      _restartTimer();
    } catch (_) {
      setState(() => _failed = true);
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_auto || _pages.length < 2) return;
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || _pages.isEmpty) return;
      setState(() => _index = (_index + 1) % _pages.length);
    });
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: Text(l.shareQrTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l.shareQrTooBig,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.shareQrTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l.shareQrEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final multi = _pages.length > 1;
    return Scaffold(
      appBar: AppBar(title: Text(l.shareQrTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l.shareQrHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: QrImageView(
                    // Ключ по содержимому — плавная смена страниц.
                    key: ValueKey(_pages[_index]),
                    data: _pages[_index],
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                    size: 300,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                multi
                    ? l.shareQrPage(_index + 1, _pages.length)
                    : l.shareQrSingle,
                style: theme.textTheme.titleSmall,
              ),
              if (multi) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _index > 0
                          ? () => setState(() => _index--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _auto,
                      onChanged: (_) => _toggleAuto(),
                    ),
                    Text(l.shareQrAuto),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _index < _pages.length - 1
                          ? () => setState(() => _index++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
