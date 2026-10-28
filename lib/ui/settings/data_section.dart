/// Секция «Данные» на экране настроек (v0.6.3): экспорт и импорт
/// резервной копии.
///
/// Экспорт: JSON-конверт BackupService → файл в каталоге базы →
/// системный шэринг (Share Plus), пользователь сам выбирает, куда
/// положить копию (Диск, Telegram, папка загрузок).
///
/// Импорт: подтверждение замены → выбор .json (File Picker, SAF —
/// без разрешений на хранилище) → валидация конверта → REPLACE-ALL
/// в одной транзакции → применение не-секретных настроек → refresh
/// всех контроллеров состояния и перепланирование напоминаний.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../../data/backup_service.dart';
import '../../data/data_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/plan_controller.dart';
import '../../state/profile_controller.dart';
import '../../state/product_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';

class DataSection extends StatelessWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        SectionHeader(l.dataSectionTitle),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: Text(l.exportDataTitle),
                subtitle: Text(l.exportDataSubtitle),
                onTap: () => _export(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(l.importDataTitle),
                subtitle: Text(l.importDataSubtitle),
                onTap: () => _confirmThenImport(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.exportHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ экспорт

  Future<void> _export(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsController>();

    try {
      final service = BackupService(AppDataStore.instance.database);
      final bundle = await service.buildBundle(
        appVersion: kAppVersion,
        settings: settings.exportSettings(),
      );
      // Каталог баз приложения: приватный, но Share Plus отдаёт файл
      // наружу через свой FileProvider с grantUriPermission.
      final dir = await getDatabasesPath();
      final file = File(p.join(dir, BackupService.suggestFileName(
        DateTime.now(),
      )));
      await file.writeAsString(service.encodeBundle(bundle), flush: true);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        title: p.basename(file.path),
      ));
      messenger.showSnackBar(
        SnackBar(content: Text(l.exportSuccess)),
      );
    } catch (e) {
      // Экспорт не должен ронять приложение: показываем ошибку и выходим.
      messenger.showSnackBar(
        SnackBar(content: Text(l.exportFailed)),
      );
    }
  }

  // ------------------------------------------------------------ импорт

  Future<void> _confirmThenImport(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.importConfirmTitle),
        content: Text(l.importConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.importConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _pickAndImport(context);
  }

  Future<void> _pickAndImport(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Контроллеры захватываем до асинхронных разрывов (lint use_build_context_synchronously).
    final settings = context.read<SettingsController>();
    final products = context.read<ProductController>();
    final profile = context.read<ProfileController>();
    final plans = context.read<PlanController>();

    final PlatformFile? pickedFile;
    try {
      pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (_) {
      // Пользователь отменил выбор или системный пикер недоступен.
      return;
    }
    if (pickedFile == null) return;

    Map<String, Object?> envelope;
    try {
      final bytes = await pickedFile.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('корень файла не объект');
      }
      envelope = decoded;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.importNotBackup)));
      return;
    }

    final service = BackupService(AppDataStore.instance.database);
    final ImportResult result;
    try {
      result = await service.importBundle(envelope);
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (e.kind) {
          BackupError.notBackup => l.importNotBackup,
          BackupError.newerVersion => l.importNewerVersion,
          BackupError.corrupted => l.importFailed,
        }),
      ));
      return;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.importFailed)));
      return;
    }

    // Настройки — после успешной замены базы (не-секретные, санитизированы).
    final rawSettings = envelope['settings'];
    if (rawSettings is Map) {
      await settings
          .applyBackupSettings(rawSettings.cast<String, Object?>());
    }

    // Обновить состояние экранов. products.refresh() заодно
    // перепланирует напоминания (reminderSync внедрён в контроллер,
    // отпечаток входов увидит новые продукты и настройки уведомлений).
    await products.refresh();
    await profile.load();
    await plans.loadHistory();

    messenger.showSnackBar(SnackBar(
      content: Text(l.importSuccess(result.products, result.plans)),
    ));
  }
}
