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
import '../../scan/aldi_lookup.dart';
import '../../scan/kroger_lookup.dart';
import '../../scan/mercadona_lookup.dart';
import '../../scan/openprices_lookup.dart';
import '../../scan/price_source.dart';
import '../../scan/pyaterochka_lookup.dart';
import '../../scan/wegmans_lookup.dart';
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

  // Автоподстановка цены (v0.5.6, источники цен): состояние поиска.
  PriceHit? _priceHit;
  bool _priceLoading = false;
  bool _priceMissed = false;
  bool _priceNotConfigured = false;
  bool _barcodeMissing = false;
  PriceFailReason? _priceFail;
  String _currencySymbol = '₽';

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

  /// Автопоиск цены включён и источник настроен?
  bool get _priceActive {
    final settings = context.read<SettingsController>();
    return settings.priceLookupEnabled && settings.priceSourceReady;
  }

  /// Тихая автоподстановка: только если фича включена, цены ещё нет
  /// и имя (или штрих-код для Open Prices) уже заполнено. Никаких
  /// диалогов — не вышло, значит поле остаётся пустым.
  void _maybeAutoFetchPrice() {
    final hasPrice = widget.existing?.price != null ||
        _price.text.trim().isNotEmpty;
    if (!_priceActive || hasPrice) return;
    final settings = context.read<SettingsController>();
    if (settings.priceSourceKind == 'open_prices') {
      if (_barcode.text.trim().isEmpty) return;
    } else if (!_nameValid) {
      return;
    }
    _fetchPrice();
  }

  Future<void> _fetchPrice() async {
    final settings = context.read<SettingsController>();
    final kind = settings.priceSourceKind;
    if (!settings.priceLookupEnabled) return;

    // Предварительные проверки без сети: у Open Prices нужен штрих-код,
    // у остальных — настроенный источник (SAP-код / ключи Kroger).
    if (kind == 'open_prices' && _barcode.text.trim().isEmpty) {
      setState(() {
        _priceLoading = false;
        _barcodeMissing = true;
        _priceNotConfigured = false;
        _priceMissed = false;
        _priceFail = null;
      });
      return;
    }
    if (!settings.priceSourceReady) {
      setState(() {
        _priceLoading = false;
        _priceNotConfigured = true;
        _barcodeMissing = false;
        _priceMissed = false;
        _priceFail = null;
      });
      return;
    }

    setState(() {
      _priceLoading = true;
      _priceNotConfigured = false;
      _barcodeMissing = false;
      _priceMissed = false;
      _priceFail = null;
    });

    try {
      final List<PriceHit> hits;
      switch (kind) {
        case 'kroger':
          hits = await context.read<KrogerService>().search(
                clientId: settings.krogerClientId,
                clientSecret: settings.krogerClientSecret,
                locationId: settings.krogerLocationId,
                query: _name.text.trim(),
              );
          break;
        case 'mercadona':
          hits = await context
              .read<MercadonaService>()
              .search(query: _name.text.trim());
          break;
        case 'aldi':
          hits = await context
              .read<AldiService>()
              .search(query: _name.text.trim());
          break;
        case 'wegmans':
          hits = await context.read<WegmansService>().search(
                subscriptionKey: settings.wegmansKey,
                storeNumber: settings.wegmansStoreNumber,
                query: _name.text.trim(),
              );
          break;
        case 'open_prices':
          hits = await context
              .read<OpenPricesService>()
              .lookupBarcode(_barcode.text.trim());
          break;
        case 'pyaterochka':
        default:
          hits = await context.read<PyaterochkaService>().search(
                storeCode: settings.pyaterochkaStoreCode,
                query: _name.text.trim(),
              );
          break;
      }
      if (!mounted) return;
      final best = kind == 'open_prices'
          ? (hits.isEmpty ? null : hits.first)
          : pickBestPriceHit(hits, _name.text.trim());
      setState(() {
        _priceLoading = false;
        if (best == null) {
          _priceMissed = true;
        } else {
          _priceHit = best;
          _currencySymbol = best.currencySymbol;
          _price.text = _fmtPrice(best.price);
          _priceTouched = false; // автоподстановка, не ручной ввод
        }
      });
    } on PriceUnavailable catch (e) {
      if (!mounted) return;
      setState(() {
        _priceLoading = false;
        _priceFail = e.reason;
      });
    } catch (e) {
      // NET-6 (аудит 2026-10-28): TypeError/NoSuchMethodError от кривого
      // JSON неофициальных API — это Error, а не Exception: раньше он
      // уходил в unhandled zone (запрос не await-ится) и _priceLoading
      // оставался true навсегда — вечный спиннер кнопки цены до закрытия
      // формы. Любая неожиданная ошибка трактуется как недоступность цены.
      if (!mounted) return;
      setState(() {
        _priceLoading = false;
        _priceFail = PriceFailReason.network;
      });
    }
  }

  static String _fmtPrice(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  /// Поле цены: ручной ввод всегда доступен; кнопка автоподстановки,
  /// статусы и подсказки — только при включённой экспериментальной фиче
  /// «Цены» (источник — в настройках).
  Widget _buildPriceField(AppLocalizations l, ThemeData theme) {
    final priceOn =
        context.read<SettingsController>().priceLookupEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _price,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.productFieldPrice,
            suffixText: _currencySymbol,
            suffixIcon: priceOn
                ? IconButton(
                    icon: _priceLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: l.priceRefresh,
                    onPressed: _priceLoading ? null : _fetchPrice,
                  )
                : null,
          ),
          onChanged: (_) => _priceTouched = true,
        ),
        if (priceOn) ...[
          const SizedBox(height: 4),
          if (_priceLoading) ...[
            Text(l.priceSearching,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            // UI-8 (аудит 2026-10-28): сборка индекса Mercadona — до 60 с
            // даже с бюджетом NET-7; вместо молчащего спиннера — прогресс
            // «N из 152» и возможность остановить (скачанное сохранится).
            ValueListenableBuilder<(int, int)?>(
              valueListenable:
                  context.read<MercadonaService>().buildProgress,
              builder: (context, progress, _) {
                if (progress == null) return const SizedBox.shrink();
                final (done, total) = progress;
                if (total <= 0) return const SizedBox.shrink();
                return Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: done / total,
                        minHeight: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.priceIndexProgress(done, total),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed: context
                          .read<MercadonaService>()
                          .requestCancelBuild,
                      child: Text(l.priceIndexCancel),
                    ),
                  ],
                );
              },
            ),
          ] else if (_priceHit != null)
            Text(l.priceMatched(_priceHit!.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant))
          else if (_priceFail != null)
            Text(
              switch (_priceFail!) {
                PriceFailReason.blocked => l.priceUnavailable,
                PriceFailReason.network => l.priceNoNetwork,
                PriceFailReason.auth => l.priceAuthError,
              },
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error),
            )
          else if (_priceNotConfigured)
            Text(l.priceNotConfigured,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error))
          else if (_barcodeMissing)
            Text(l.priceBarcodeRequired,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error))
          else if (_priceMissed)
            Text(
              context.read<SettingsController>().priceSourceKind ==
                      'open_prices'
                  ? l.priceBarcodeNotFound
                  : l.priceNotFound,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
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
        : (_priceHit != null
            ? context.read<SettingsController>().priceSourceKind
            : null);
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
