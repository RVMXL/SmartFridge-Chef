/// Экран «Мой холодильник» (Шаг 3, ТЗ): список продуктов с цветовой
/// индикацией свежести, поиск, сортировка, CRUD и быстрый ввод
/// (штрих-код / чек / вручную).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/freshness.dart';
import '../../data/models/product.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../scan/barcode_lookup.dart';
import '../../state/product_controller.dart';
import '../scan/receipt_screen.dart';
import '../scan/scanner_screen.dart';
import '../share/receive_qr_screen.dart';
import '../share/share_qr_screen.dart';
import '../widgets/common.dart';
import 'product_edit_sheet.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductController>().refresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAddOptions() async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(l.fridgeAddBarcode),
              onTap: () => Navigator.of(sheetCtx).pop(0),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l.fridgeAddReceipt),
              onTap: () => Navigator.of(sheetCtx).pop(1),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.fridgeAddManual),
              onTap: () => Navigator.of(sheetCtx).pop(2),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 0:
        await _openScanner();
      case 1:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ReceiptScreen(),
        ));
      case 2:
        await showProductEditSheet(context);
    }
  }

  Future<void> _openShareMenu() async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                l.shareMenuTitle,
                style: Theme.of(sheetCtx).textTheme.titleSmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l.shareShowQr),
              subtitle: Text(l.shareShowQrHint),
              onTap: () => Navigator.of(sheetCtx).pop(0),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(l.shareReceiveQr),
              subtitle: Text(l.shareReceiveQrHint),
              onTap: () => Navigator.of(sheetCtx).pop(1),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          choice == 0 ? const ShareQrScreen() : const ReceiveQrScreen(),
    ));
  }

  Future<void> _openScanner() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) return;

    final controller = context.read<ProductController>();
    final existing = await controller.findByBarcode(barcode);
    if (!mounted) return;
    final l = AppLocalizations.of(context);

    if (existing != null) {
      // Частично-уникальный индекс Шага 1: один код — одна карточка.
      // Докупили — увеличиваем количество у существующей позиции.
      final action = await showDialog<_DuplicateAction>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          title: Text(l.duplicateTitle),
          content: Text(l.duplicateBody(
            existing.name,
            DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
                .format(existing.expiryDate),
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(),
              child: Text(l.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dlgCtx)
                  .pop(_DuplicateAction.edit),
              child: Text(l.duplicateOpen),
            ),
            if (existing.unit == ProductUnit.pcs)
              FilledButton(
                onPressed: () => Navigator.of(dlgCtx)
                    .pop(_DuplicateAction.addOne),
                child: Text(l.duplicateAddOne),
              ),
          ],
        ),
      );
      if (!mounted || action == null) return;
      if (action == _DuplicateAction.addOne) {
        await controller.update(
          existing.copyWith(quantity: existing.quantity + 1),
        );
      } else if (action == _DuplicateAction.edit) {
        await showProductEditSheet(context, existing: existing);
      }
      return;
    }

    // Новый код: автопоиск — локальный кэш, затем открытая база
    // Open Food Facts. Нашлось — форма уже заполнена именем и категорией
    // (а категория задаёт типовой срок); не нашлось/нет сети — прежний
    // ручной путь с пояснением.
    final lookup = context.read<BarcodeLookupService>();
    final langCode = Localizations.localeOf(context).languageCode;
    // Запрос стартует до диалога, чтобы кэш-попадание почти не мигало.
    final lookupFuture = lookup.lookup(barcode, langCode: langCode);
    final found = await showDialog<BarcodeLookupResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BarcodeLookupDialog(future: lookupFuture),
    );
    if (!mounted) return;

    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.scanLookupMiss)),
      );
      await showProductEditSheet(context, initialBarcode: barcode);
      return;
    }
    await showProductEditSheet(
      context,
      initialBarcode: barcode,
      initialName: found.name,
      initialCategory: found.category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctrl = context.watch<ProductController>();
    final items = ctrl.visible;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: ctrl.setQuery,
              )
            : Text(l.fridgeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: l.shareMenuTitle,
            onPressed: _openShareMenu,
          ),
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  ctrl.setQuery('');
                }
              });
            },
          ),
          PopupMenuButton<FridgeSort>(
            icon: const Icon(Icons.sort),
            tooltip: l.sortTooltip,
            onSelected: ctrl.setSort,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: FridgeSort.expiry,
                child: Text(l.sortExpiry),
              ),
              PopupMenuItem(
                value: FridgeSort.name,
                child: Text(l.sortName),
              ),
              PopupMenuItem(
                value: FridgeSort.category,
                child: Text(l.sortCategory),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddOptions,
        icon: const Icon(Icons.add),
        label: Text(l.commonAdd),
      ),
      body: ctrl.loading && ctrl.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ctrl.error != null && ctrl.products.isEmpty
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: l.dbOpenError,
                  body: ctrl.error ?? '',
                  action: TextButton(
                    onPressed: ctrl.refresh,
                    child: Text(l.retry),
                  ),
                )
              : RefreshIndicator(
                    onRefresh: ctrl.refresh,
                    child: items.isEmpty
                        ? ListView(children: [_buildEmpty(context, ctrl)])
                        : _FridgeList(items: items),
                  ),
    );
  }

  Widget _buildEmpty(BuildContext context, ProductController ctrl) {
    final l = AppLocalizations.of(context);
    final hasQuery = ctrl.query.trim().isNotEmpty;
    if (hasQuery) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 12),
            Text(l.emptySearchTitle,
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.kitchen_outlined, size: 56),
          const SizedBox(height: 12),
          Text(l.fridgeEmptyTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l.fridgeEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text(
            l.swipeHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

enum _DuplicateAction { addOne, edit }

/// Список карточек продуктов.
class _FridgeList extends StatelessWidget {
  const _FridgeList({required this.items});

  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _Legend(),
        const SizedBox(height: 8),
        for (final p in items)
          _ProductCard(
            key: ValueKey(p.id ?? p.name),
            product: p,
            dismissEnabled: true,
          ),
        const SizedBox(height: 8),
        Text(
          l.swipeHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Легенда цветов свежести.
class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget dot(Freshness f, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: freshnessColor(context, f),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          dot(Freshness.fresh, l.freshnessFresh),
          dot(Freshness.expiringSoon, l.freshnessExpiring),
          dot(Freshness.expired, l.freshnessExpired),
        ],
      ),
    );
  }
}

/// Карточка продукта: цветная полоса свежести, статус, дата, действия.
class _ProductCard extends StatelessWidget {
  const _ProductCard({super.key, required this.product, required this.dismissEnabled});

  final Product product;
  final bool dismissEnabled;

  Future<bool> _confirmDismiss(BuildContext context, DismissDirection dir) async {
    final l = AppLocalizations.of(context);
    // Контроллер захватываем до async-разрывов, чтобы не держать context.
    final controller = context.read<ProductController>();
    if (dir == DismissDirection.startToEnd) {
      // Свайп вправо — съел.
      await controller.setStatus(product.id!, ProductStatus.consumed);
      return true;
    }
    // Свайп влево — меню выбора: выбросить или удалить навсегда.
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l.actionDiscard),
              onTap: () => Navigator.of(sheetCtx).pop('discard'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: Text(l.commonDelete),
              onTap: () => Navigator.of(sheetCtx).pop('delete'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: Text(l.commonCancel),
              onTap: () => Navigator.of(sheetCtx).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice == 'discard') {
      await controller.setStatus(product.id!, ProductStatus.discarded);
      return true;
    }
    if (choice == 'delete') {
      await controller.delete(product.id!);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final freshness =
        freshnessFor(product.expiryDate, soonDays: kExpiringSoonDays);
    final color = freshnessColor(context, freshness);
    final left = daysLeftUntil(product.expiryDate);
    final dateFmt =
        DateFormat.yMMMd(Localizations.localeOf(context).languageCode);

    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showProductEditSheet(context, existing: product),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 68,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ListTile(
                minVerticalPadding: 12,
                title: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${categoryLabel(l, product.category)} · '
                  '${quantityText(l, product)}\n'
                  '${l.expiryOn(dateFmt.format(product.expiryDate))} — '
                  '${freshness == Freshness.expired ? l.freshnessExpired : l.daysLeft(left)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
              ),
            ),
            if (product.barcode != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.qr_code_2,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );

    if (!dismissEnabled) return card;
    return Dismissible(
      key: ValueKey('dismiss-${product.id ?? product.name}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) => _confirmDismiss(context, dir),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: theme.colorScheme.primaryContainer,
        child: Icon(Icons.restaurant,
            color: theme.colorScheme.onPrimaryContainer),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      child: card,
    );
  }
}

/// Диалог ожидания автопоиска штрих-кода: крутилка, пока выполняется
/// запрос; когда будущий результат завершился (найдено/не найдено/ошибка
/// сети) — сам закрывается и возвращает результат в [showDialog].
class _BarcodeLookupDialog extends StatelessWidget {
  const _BarcodeLookupDialog({required this.future});

  final Future<BarcodeLookupResult?> future;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<BarcodeLookupResult?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.waiting) {
          // Завершено: закрываем диалог после отрисовки кадра.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pop(
                snap.hasError ? null : snap.data,
              );
            }
          });
        }
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(l.scanLookupWaiting)),
            ],
          ),
        );
      },
    );
  }
}
