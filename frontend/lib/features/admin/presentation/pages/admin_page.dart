import 'package:flowers/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowers/core/widgets/app_message.dart';
import 'package:flowers/core/widgets/async_body.dart';
import 'package:flowers/features/admin/domain/entities/role.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Админ')),
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
            loading: state.loading && state.roles.isEmpty,
            error: state.error,
            onRetry: () => context.read<AdminCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Роли',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (state.roles.isEmpty)
                  const Text('Нет ролей')
                else
                  ...state.roles.map(_RoleTile.new),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _showCreateUserDialog(context, state.roles),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Создать пользователя'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showCreateRoleDialog(context),
                  icon: const Icon(Icons.security),
                  label: const Text('Создать роль'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile(this.role);

  final Role role;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(role.name),
      subtitle: Text(role.permissions.join(', ')),
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
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
                  ...roles.map(
                    (role) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(role.name),
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
  try {
    await cubit.createUser(
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text,
      roleIds: selected.toList(),
    );
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания пользователя');
    }
  }
}

Future<void> _showCreateRoleDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final permsCtrl = TextEditingController();
  final cubit = context.read<AdminCubit>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Новая роль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          TextField(
            controller: permsCtrl,
            decoration: const InputDecoration(
              labelText: 'Права (через запятую)',
            ),
          ),
        ],
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
    ),
  );
  if (ok != true) return;
  try {
    await cubit.createRole(
      name: nameCtrl.text.trim(),
      permissions: permsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  } catch (_) {
    if (context.mounted) {
      AppMessage.showError(context, 'Ошибка создания роли');
    }
  }
}
