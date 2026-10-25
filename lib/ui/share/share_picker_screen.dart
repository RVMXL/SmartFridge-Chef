/// Экран ручного выбора продуктов для QR-передачи (v0.5.1).
///
/// Открывается из меню «Обмен продуктами → Показать QR → Выбрать
/// вручную». По умолчанию отмечены все несъеденные — удобно вычеркнуть
/// лишнее (например, съеденное вторым членом семьи). Возвращает
/// отмеченный список в ShareQrScreen.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common.dart';

class SharePickerScreen extends StatefulWidget {
  const SharePickerScreen({super.key, required this.products});

  /// Все активные продукты на выбор (уже отсортированы по сроку в DAO).
  final List<Product> products;

  @override
  State<SharePickerScreen> createState() => _SharePickerScreenState();
}

class _SharePickerScreenState extends State<SharePickerScreen> {
  late final Set<int> _selected;
  late final List<Product> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.products]
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    _selected = {
      // Все отмечены: ручной режим обычно «передать всё, кроме...».
      for (final p in widget.products)
        if (p.id != null) p.id!,
    };
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selected.addAll({for (final p in _sorted) if (p.id != null) p.id!});
      } else {
        _selected.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_sorted.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.sharePickTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l.sharePickEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.sharePickTitle),
        actions: [
          IconButton(
            tooltip: l.sharePickAll,
            icon: const Icon(Icons.select_all),
            onPressed: () => _toggleAll(true),
          ),
          IconButton(
            tooltip: l.sharePickNone,
            icon: const Icon(Icons.deselect),
            onPressed: () => _toggleAll(false),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _sorted.length,
        itemBuilder: (context, i) {
          final p = _sorted[i];
          final id = p.id!;
          final selected = _selected.contains(id);
          return CheckboxListTile(
            value: selected,
            onChanged: (v) => setState(
              () => v == true ? _selected.add(id) : _selected.remove(id),
            ),
            title: Text(p.name),
            subtitle: Text(
              '${quantityLabel(p)} · ${dateLabel(p)}',
              style: theme.textTheme.bodySmall,
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(
                      [
                        for (final p in _sorted)
                          if (_selected.contains(p.id)) p,
                      ],
                    ),
            child: Text(l.sharePickSend(_selected.length)),
          ),
        ),
      ),
    );
  }

  String quantityLabel(Product p) {
    final l = AppLocalizations.of(context);
    return quantityText(l, p);
  }

  String dateLabel(Product p) {
    final localeTag = Localizations.localeOf(context).languageCode;
    return DateFormat.yMMMd(localeTag).format(p.expiryDate);
  }
}
