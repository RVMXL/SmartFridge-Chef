/// Форма добавления/редактирования продукта (Шаг 3).
///
/// Открывается модальным листом из холодильника, сканера и чека.
/// [initialBarcode], [initialName] и [initialCategory] приходят из
/// сканера/автопоиска/OCR — пользователь дозаполняет остальное.
/// Дата по умолчанию — типовой срок категории одним тапом.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/freshness.dart';
import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common.dart';

Future<void> showProductEditSheet(
  BuildContext context, {
  Product? existing,
  String? initialBarcode,
  String? initialName,
  ProductCategory? initialCategory,
}) {
  return showModalBottomSheet(
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
  late ProductCategory _category;
  late ProductUnit _unit;
  late DateTime _expiry;
  bool _triedSave = false;

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
    _category =
        p?.category ?? widget.initialCategory ?? ProductCategory.other;
    _unit = p?.unit ?? ProductUnit.pcs;
    _expiry = p?.expiryDate ??
        DateTime.now().add(Duration(days: _category.defaultShelfLifeDays));
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _barcode.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _nameValid => _name.text.trim().isNotEmpty;

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
    final product = (widget.existing ?? Product(
      name: '',
      category: _category,
      expiryDate: _expiry,
      addedAt: DateTime.now(),
    )).copyWith(
      name: _name.text.trim(),
      category: _category,
      barcode: barcode.isEmpty ? null : barcode,
      quantity: qty <= 0 ? 1.0 : qty,
      unit: _unit,
      expiryDate: _expiry,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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
