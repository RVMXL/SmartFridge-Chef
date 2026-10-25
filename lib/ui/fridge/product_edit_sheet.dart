/// Форма добавления/редактирования продукта (Шаг 3).
///
/// Открывается модальным листом из холодильника, сканера и чека.
/// [initialBarcode], [initialName] и [initialCategory] приходят из
/// сканера/автопоиска/OCR — пользователь дозаполняет остальное.
/// Дата по умолчанию — типовой срок категории одним тапом.
/// Возвращает сохранённый [Product] или null, если пользователь закрыл
/// форму без сохранения. Вызывающий код ОБЯЗАН сохранить результат
/// через ProductController.add/update (см. _saveSheetResult во fridge_screen).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/freshness.dart';
import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../scan/pyaterochka_lookup.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';

Future<Product?> showProductEditSheet(
  BuildContext context, {
  Product? existing,
  String? initialBarcode,
  String? initialName,
  ProductCategory? initialCategory,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProductEditSheet(
      existing: existing,
      initialBarcode: initialBarcode,
      initialName: initialName,
      initialCategory: initialCategory,
    ),
  );
}

class ProductEditSheet extends StatefulWidget {
  const ProductEditSheet({
    super.key,
    this.existing,
    this.initialBarcode,
    this.initialName,
    this.initialCategory,
  });

  final Product? existing;
  final String? initialBarcode;
  final String? initialName;
  final ProductCategory? initialCategory;

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<ProductEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _barcode;
  late final TextEditingController _notes;
  late final TextEditingController _price;
  late ProductCategory _category;
  late ProductUnit _unit;
  late DateTime _expiry;
  bool _triedSave = false;

  // Цены Пятёрочки (v0.5.5): состояние автоподстановки.
  PyaterochkaHit? _pyatHit;
  bool _pyatLoading = false;
  bool _pyatMissed = false;
  bool _pyatStoreMissing = false;
  PyaterochkaFailReason? _pyatFail;

  /// Пользователь правил цену руками после последней автоподстановки.
  bool _priceTouched = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? widget.initialName ?? '');
    _quantity =
        TextEditingController(text: _fmtQty(p?.quantity ?? 1.0));
    _barcode =
        TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _price = TextEditingController(
        text: p?.price == null ? '' : _fmtPrice(p!.price!));
    _category =
        p?.category ?? widget.initialCategory ?? ProductCategory.other;
    _unit = p?.unit ?? ProductUnit.pcs;
    _expiry = p?.expiryDate ??
        DateTime.now().add(Duration(days: _category.defaultShelfLifeDays));
    // Автоподстановка цены (если включена и цены ещё нет) — после кадра,
    // чтобы context.read был легален.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAutoFetchPrice();
    });
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _barcode.dispose();
    _notes.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _nameValid => _name.text.trim().isNotEmpty;

  /// Автопоиск цены включён и магазин выбран?
  bool get _pyatActive {
    final settings = context.read<SettingsController>();
    return settings.pyaterochkaEnabled &&
        settings.pyaterochkaStoreCode.trim().isNotEmpty;
  }

  /// Тихая автоподстановка: только если фича включена, цены ещё нет
  /// и имя уже заполнено (сканером/OFF). Никаких диалогов — не вышло,
  /// значит поле остаётся пустым.
  void _maybeAutoFetchPrice() {
    final hasPrice = widget.existing?.price != null ||
        _price.text.trim().isNotEmpty;
    if (!_pyatActive || hasPrice || !_nameValid) return;
    _fetchPrice();
  }

  Future<void> _fetchPrice() async {
    final settings = context.read<SettingsController>();
    final service = context.read<PyaterochkaService>();
    final store = settings.pyaterochkaStoreCode.trim();
    if (store.isEmpty) {
      setState(() {
        _pyatStoreMissing = true;
        _pyatMissed = false;
        _pyatFail = null;
      });
      return;
    }
    setState(() {
      _pyatLoading = true;
      _pyatStoreMissing = false;
      _pyatMissed = false;
      _pyatFail = null;
    });
    try {
      final hits = await service.search(
        storeCode: store,
        query: _name.text.trim(),
      );
      if (!mounted) return;
      final best = pickBestPyaterochkaHit(hits, _name.text.trim());
      setState(() {
        _pyatLoading = false;
        if (best == null) {
          _pyatMissed = true;
        } else {
          _pyatHit = best;
          _price.text = _fmtPrice(best.price);
        }
      });
    } on PyaterochkaUnavailable catch (e) {
      if (!mounted) return;
      setState(() {
        _pyatLoading = false;
        _pyatFail = e.reason;
      });
    }
  }

  static String _fmtPrice(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  /// Поле цены: ручной ввод всегда доступен; кнопка автоподстановки,
  /// статусы и подсказки — только при включённой экспериментальной фиче
  /// «Цены Пятёрочки».
  Widget _buildPriceField(AppLocalizations l, ThemeData theme) {
    final pyatOn = context.read<SettingsController>().pyaterochkaEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _price,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.productFieldPrice,
            suffixText: '₽',
            suffixIcon: pyatOn
                ? IconButton(
                    icon: _pyatLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: l.pyatRefresh,
                    onPressed: _pyatLoading ? null : _fetchPrice,
                  )
                : null,
          ),
          onChanged: (_) => _priceTouched = true,
        ),
        if (pyatOn) ...[
          const SizedBox(height: 4),
          if (_pyatLoading)
            Text(l.pyatSearching,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant))
          else if (_pyatHit != null)
            Text(l.pyatMatched(_pyatHit!.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant))
          else if (_pyatFail != null)
            Text(
              _pyatFail == PyaterochkaFailReason.blocked
                  ? l.pyatUnavailable
                  : l.pyatNoNetwork,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error),
            )
          else if (_pyatStoreMissing)
            Text(l.pyatStoreRequired,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error))
          else if (_pyatMissed)
            Text(l.pyatNotFound,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry.isBefore(now) ? now : _expiry,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiry = dateOnly(picked));
  }

  Future<void> _save() async {
    setState(() => _triedSave = true);
    if (!_nameValid) return;
    final qty = double.tryParse(_quantity.text.replaceAll(',', '.')) ?? 1.0;
    final barcode = _barcode.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.').trim());
    final base = widget.existing ??
        Product(
          name: '',
          category: _category,
          expiryDate: _expiry,
          addedAt: DateTime.now(),
        );
    // Источник цены этой сессии: правка руками сильнее автоподстановки;
    // null — цену не трогали, прежние метаданные сохраняются как есть.
    final String? freshSource = _priceTouched
        ? 'manual'
        : (_pyatHit != null ? 'pyaterochka' : null);
    final product = base.copyWith(
      name: _name.text.trim(),
      category: _category,
      barcode: barcode.isEmpty ? null : barcode,
      quantity: qty <= 0 ? 1.0 : qty,
      unit: _unit,
      expiryDate: _expiry,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      clearPrice: price == null,
      clearPriceUpdatedAt: price == null,
      clearPriceSource: price == null,
      price: price,
      priceUpdatedAt: price != null && freshSource != null
          ? DateTime.now()
          : null,
      priceSource: freshSource,
    );
    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l.productNew : l.productEditTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null && widget.initialName == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.productFieldName,
                hintText: l.productNameHint,
                errorText: !_nameValid && _triedSave
                    ? l.productNameRequired
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l.productFieldCategory),
              items: [
                for (final c in ProductCategory.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text(categoryLabel(l, c)),
                  ),
              ],
              onChanged: (c) {
                if (c == null) return;
                setState(() {
                  _category = c;
                  // Смена категории подтягивает типовой срок (Шаг 1: 12
                  // категорий с дефолтами) — если продукт новый.
                  if (widget.existing == null) {
                    _expiry = DateTime.now()
                        .add(Duration(days: c.defaultShelfLifeDays));
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: l.productFieldQuantity),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ProductUnit>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: ' '),
                    items: [
                      for (final u in ProductUnit.values)
                        DropdownMenuItem(
                          value: u,
                          child: Text(unitLabel(l, u)),
                        ),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPriceField(l, theme),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.productFieldExpiry,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.event_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat.yMMMd(Localizations.localeOf(context)
                                    .languageCode)
                                .format(_expiry),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: _pickDate,
                          child: Text(l.productExpiryPick),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: Text(l.productQuickPlus2),
                          onPressed: () => setState(() {
                            _expiry = dateOnly(DateTime.now())
                                .add(const Duration(days: 2));
                          }),
                        ),
                        ActionChip(
                          label: Text(l.productQuickPlus7),
                          onPressed: () => setState(() {
                            _expiry = dateOnly(DateTime.now())
                                .add(const Duration(days: 7));
                          }),
                        ),
                        Chip(
                          label: Text(l.productDefaultShelf(
                              _category.defaultShelfLifeDays)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.productFieldBarcode,
                hintText: l.productBarcodeEmpty,
                suffixIcon: _barcode.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _barcode.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l.productFieldNotes),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
