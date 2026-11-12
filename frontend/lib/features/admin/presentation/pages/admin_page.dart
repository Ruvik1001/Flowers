import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/l10n/labels.dart';
import 'package:flowers/core/widgets/app_dialog.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/app_page_scaffold.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/core/widgets/entity_list_tile.dart';
import 'package:flowers/core/widgets/section_header.dart';
import 'package:flowers/core/widgets/soft_card.dart';
import 'package:flowers/core/widgets/status_chip.dart';
import 'package:flowers/features/admin/domain/entities/role.dart';
import 'package:flowers/features/admin/domain/entities/staff_user.dart';
import 'package:flowers/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:flowers/features/admin/presentation/cubit/admin_state.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminCubit(Di.I.admin)..load(),
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatelessWidget {
  const _AdminView();

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: const Text('Админ'),
      body: BlocConsumer<AdminCubit, AdminState>(
        listenWhen: (p, c) =>
            p.lastMessage != c.lastMessage && c.lastMessage != null,
        listener: (context, state) {
          if (state.lastMessage != null) {
            AppMessage.showSuccess(context, state.lastMessage!);
          }
        },
        builder: (context, state) {
          return AsyncBody(
            loading: state.loading &&
                state.roles.isEmpty &&
                state.users.isEmpty,
            error: state.error,
            onRetry: () => context.read<AdminCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const SectionHeader(
                  title: 'Сотрудники',
                  subtitle: 'Учётные записи и роли',
                ),
                if (state.users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Нет пользователей или нет доступа к списку'),
                  )
                else
                  ...state.users.map(_UserTile.new),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SoftCard(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _showCreateUserDialog(context, state.roles),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Создать пользователя'),
                    ),
                  ),
                ),
                const SectionHeader(
                  title: 'Роли',
                  subtitle: 'Права доступа сотрудников',
                ),
                if (state.roles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Нет ролей'),
                  )
                else
                  ...state.roles.map(_RoleTile.new),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SoftCard(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCreateRoleDialog(context),
                      icon: const Icon(Icons.security),
                      label: const Text('Создать роль'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile(this.user);

  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    final roles = user.roles.isEmpty
        ? (user.isAdmin ? 'Админ' : 'Без роли')
        : user.roles.join(', ');
    return EntityListTile(
      title: Text(user.email),
      subtitle: Text(roles),
      trailing: StatusChip(
        label: user.isActive
            ? (user.isAdmin ? 'Админ' : 'Активен')
            : 'Отключён',
        tone: user.isActive
            ? (user.isAdmin ? StatusTone.accent : StatusTone.success)
            : StatusTone.danger,
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile(this.role);

  final Role role;

  @override
  Widget build(BuildContext context) {
    return EntityListTile(
      title: Text(role.name),
      subtitle: Text(Labels.permissionsList(role.permissions)),
    );
  }
}

Future<void> _showCreateUserDialog(
  BuildContext context,
  List<Role> roles,
) async {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final selected = <String>{if (roles.isNotEmpty) roles.first.id};
  final cubit = context.read<AdminCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новый пользователь'),
            content: AppDialogScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Эл. почта'),
                  ),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Роли',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                  ),
                  if (roles.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Сначала создайте роль'),
                    )
                  else
                    ...roles.map(
                      (role) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(role.name),
                        subtitle: Text(
                          Labels.permissionsList(role.permissions),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: selected.contains(role.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(role.id);
                            } else {
                              selected.remove(role.id);
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Создать'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;
  if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
    if (context.mounted) {
      AppMessage.showError(context, 'Укажите почту и пароль');
    }
    return;
  }
  try {
    await cubit.createUser(
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text,
      roleIds: selected.toList(),
    );
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(
        context,
        cubit.state.error ?? 'Ошибка создания пользователя',
      );
    }
  }
}

Future<void> _showCreateRoleDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final selected = <String>{};
  final cubit = context.read<AdminCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Новая роль'),
            content: AppDialogScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Права',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                  ),
                  for (final code in Labels.knownPermissions)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(code),
                      title: Text(Labels.permission(code)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selected.add(code);
                          } else {
                            selected.remove(code);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Создать'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ok != true) return;
  if (selected.isEmpty) {
    if (context.mounted) {
      AppMessage.showError(context, 'Выберите хотя бы одно право');
    }
    return;
  }
  try {
    await cubit.createRole(
      name: nameCtrl.text.trim(),
      permissions: selected.toList(),
    );
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(
        context,
        cubit.state.error ?? 'Ошибка создания роли',
      );
    }
  }
}
