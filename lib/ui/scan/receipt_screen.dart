/// Экран распознавания чека (Шаг 3): фото → ML Kit OCR → парсер чека →
/// подтверждение позиций → массовое добавление в холодильник.
///
/// Всё распознавание — на устройстве; фото никуда не отправляется.
/// Названия из OCR можно поправить прямо в списке перед добавлением.
library;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../scan/receipt_parser.dart';
import '../../state/product_controller.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  List<ReceiptCandidate> _candidates = const [];
  final Set<int> _selected = {};
  final Map<int, TextEditingController> _nameCtrls = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _recognizer.close();
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final input = InputImage.fromFilePath(picked.path);
      final result = await _recognizer.processImage(input);
      final candidates = parseReceipt(result.text);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _selected.clear();
        _selected.addAll([for (var i = 0; i < candidates.length; i++) i]);
        for (final c in _nameCtrls.values) {
          c.dispose();
        }
        _nameCtrls.clear();
        for (var i = 0; i < candidates.length; i++) {
          _nameCtrls[i] =
              TextEditingController(text: candidates[i].name);
        }
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _addSelected() async {
    final l = AppLocalizations.of(context);
    final controller = context.read<ProductController>();
    final now = DateTime.now();
    // Из чека: категория — по эвристике ключевых слов (иначе «другое»),
    // типовой срок 14 дней — пользователь поправит даты по одной, если захочет.
    final items = [
      for (final i in _selected)
        Product(
          name: (_nameCtrls[i]?.text.trim().isNotEmpty ?? false)
              ? _nameCtrls[i]!.text.trim()
              : _candidates[i].name,
          category: _categoryFor(_candidates[i]),
          quantity: _candidates[i].quantity.toDouble(),
          expiryDate: now.add(const Duration(days: 14)),
          addedAt: now,
        ),
    ];
    final saved = await controller.addAll(items);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.receiptAdded(saved))),
    );
    Navigator.of(context).pop();
  }

  /// Грубая эвристика категории по ключевым словам названия.
  ProductCategory _categoryFor(ReceiptCandidate c) {
    final n = c.name.toLowerCase();
    if (RegExp(r'молок|кефир|сметан|творог|йогурт|сыр|масло слив').hasMatch(n)) {
      return ProductCategory.dairy;
    }
    if (RegExp(r'курин|свинин|говядин|фарш|индейк|колбас|сосиск').hasMatch(n)) {
      return ProductCategory.meat;
    }
    if (RegExp(r'рыб|лосос|тунец|селедк|креветк').hasMatch(n)) {
      return ProductCategory.fish;
    }
    if (RegExp(r'хлеб|батон|булк|лаваш|пирог').hasMatch(n)) {
      return ProductCategory.bakery;
    }
    if (RegExp(r'яблок|банан|апельсин|груш|лимон|мандарин').hasMatch(n)) {
      return ProductCategory.fruits;
    }
    if (RegExp(r'помидор|огур|капуст|картош|морков|лук|перец').hasMatch(n)) {
      return ProductCategory.vegetables;
    }
    return ProductCategory.other;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.receiptTitle)),
      body: _busy
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l.receiptRecognizing),
                ],
              ),
            )
          : _candidates.isEmpty
              ? _PickerView(
                  error: _error,
                  onCamera: () => _pick(ImageSource.camera),
                  onGallery: () => _pick(ImageSource.gallery),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        l.receiptFound(_selected.length),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        l.receiptEditHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _candidates.length,
                        itemBuilder: (context, i) {
                          final c = _candidates[i];
                          return CheckboxListTile(
                            value: _selected.contains(i),
                            onChanged: (on) => setState(() {
                              if (on ?? false) {
                                _selected.add(i);
                              } else {
                                _selected.remove(i);
                              }
                            }),
                            secondary: Text(
                              c.price == null
                                  ? '×${c.quantity}'
                                  : c.price!.toStringAsFixed(2),
                              style: theme.textTheme.bodyMedium,
                            ),
                            title: TextField(
                              controller: _nameCtrls[i],
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: c.rawLine,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _candidates.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _selected.isEmpty ? null : _addSelected,
              icon: const Icon(Icons.check),
              label: Text(l.receiptAddSelected(_selected.length)),
            ),
    );
  }
}

class _PickerView extends StatelessWidget {
  const _PickerView({
    required this.onCamera,
    required this.onGallery,
    this.error,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 56),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.receiptPickCamera),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l.receiptPickGallery),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                l.receiptNotFound,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
