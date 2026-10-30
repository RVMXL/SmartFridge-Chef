/// Экран «Техника на кухне» (v0.6.6): быстрое редактирование списка
/// техники без прокрутки всего профиля питания.
///
/// Обратная сторона фичи v0.6.4: чипы техники жили в самом низу длинного
/// экрана профиля (после калоража, БЖУ, диет, аллергенов, столов
/// Певзнера и нелюбимых продуктов) и не находились — репорт владельца
/// «не могу поменять оборудование, нет вкладки». Здесь тот же список
/// (чипы [KitchenEquipment.values]) и то же правило null = «всё есть»,
/// что и в [ProfileEditScreen], но отдельная точка входа из настроек.
/// При сохранении меняется только поле equipment — остальные поля
/// профиля переносятся как есть (copyWith).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/equipment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/profile_controller.dart';
import '../widgets/common.dart';
import 'profile_edit_screen.dart';

class EquipmentEditScreen extends StatefulWidget {
  const EquipmentEditScreen({super.key});

  @override
  State<EquipmentEditScreen> createState() => _EquipmentEditScreenState();
}

class _EquipmentEditScreenState extends State<EquipmentEditScreen> {
  /// Профиль без явного списка (до v0.6.4) показывается как «всё есть» —
  /// при сохранении список становится явным, поведение меняется только
  /// если пользователь снял галочки.
  late Set<KitchenEquipment> _equipment;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileController>().profile;
    _equipment = p?.equipment?.toSet() ?? {...KitchenEquipment.values};
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final controller = context.read<ProfileController>();
    final base = controller.profile ?? PlanDefaults.profile;
    final ok = await controller.save(
      base.copyWith(equipment: _equipment.toList()),
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.profileSaved)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.profileEquipment)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.profileEquipmentHint,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final e in KitchenEquipment.values)
                FilterChip(
                  label: Text(equipmentLabel(l, e)),
                  selected: _equipment.contains(e),
                  onSelected: (on) => setState(() {
                    on ? _equipment.add(e) : _equipment.remove(e);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l.commonSave),
          ),
        ],
      ),
    );
  }
}
