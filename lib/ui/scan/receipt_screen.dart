/// Экран распознавания чека (Шаг 3): фото → OCR → парсер чека →
/// подтверждение позиций → массовое добавление в холодильник.
///
/// OCR-1 (аудит 2026-10-28, v0.6.2): два движка на устройстве —
/// Tesseract (rus.traineddata) для кириллицы + ML Kit latin для
/// латиницы, автовыбор см. [AutoOcrEngine]. Всё на устройстве; фото
/// никуда не отправляется. Названия из OCR можно поправить в списке.
library;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../scan/ocr_engine.dart';
import '../../scan/receipt_parser.dart';
import '../../state/product_controller.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, this.engine});

  /// Внедряется в тестах; null — авто (Tesseract rus + ML Kit latin).
  final OcrEngine? engine;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  late final OcrEngine _engine = widget.engine ?? AutoOcrEngine();

  List<ReceiptCandidate> _candidates = const [];
  String? _currency; // SCAN-2: валюта чека (RUB/USD/EUR/…)
  final Set<int> _selected = {};
  final Map<int, TextEditingController> _nameCtrls = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _engine.dispose();
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
      final input = picked.path;
      final outcome = await _engine.recognize(input);
      final result = parseReceiptDetailed(outcome.text);
      final candidates = result.candidates;
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _currency = result.currency;
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
    // SCAN-2 (v0.6.2): валюта из чека (₽/$/€/₸/£), null → дефолт базы.
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
          price: _candidates[i].price,
          currency: _currency,
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
  /// Аудит 2026-10-28 (OCR): EN-чеки распознаются, но категоризатор
  /// понимал только русские слова — добавлены EN-стемы.
  ProductCategory _categoryFor(ReceiptCandidate c) {
    final n = c.name.toLowerCase();
    if (RegExp(
        'молок|кефир|сметан|творог|йогурт|сыр|масло слив|'
        'milk|cheese|yogurt|yoghurt|kefir|sour cream|cottage|butter|cream')
        .hasMatch(n)) {
      return ProductCategory.dairy;
    }
    if (RegExp(
        'курин|свинин|говядин|фарш|индейк|колбас|сосиск|'
        'chicken|pork|beef|turkey|minced|sausage|ham|bacon').hasMatch(n)) {
      return ProductCategory.meat;
    }
    if (RegExp('рыб|лосос|тунец|селедк|креветк|'
        'fish|salmon|tuna|herring|shrimp|cod|trout').hasMatch(n)) {
      return ProductCategory.fish;
    }
    if (RegExp('хлеб|батон|булк|лаваш|пирог|'
        'bread|bun|baguette|loaf|roll|pastry|bagel').hasMatch(n)) {
      return ProductCategory.bakery;
    }
    if (RegExp('яблок|банан|апельсин|груш|лимон|мандарин|'
        'apple|banana|orange|pear|lemon|grape|berry|berries|strawberry')
        .hasMatch(n)) {
      return ProductCategory.fruits;
    }
    if (RegExp('помидор|огур|капуст|картош|морков|лук|перец|'
        'tomato|cucumber|cabbage|potato|carrot|onion|pepper|lettuce')
        .hasMatch(n)) {
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        l.receiptOcrNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
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
