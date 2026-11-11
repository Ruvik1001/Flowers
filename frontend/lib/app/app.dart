import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flowers/app/di.dart';
import 'package:flowers/app/router/app_router.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowers/l10n/app_localizations.dart';

class FlowersApp extends StatefulWidget {
  const FlowersApp({super.key});

  @override
  State<FlowersApp> createState() => _FlowersAppState();
}

class _FlowersAppState extends State<FlowersApp> {
  late final AuthCubit _authCubit;
  late final AuthRefresh _refresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(Di.I.auth)..bootstrap();
    _refresh = AuthRefresh();
    _authCubit.stream.listen((_) => _refresh.ping());
    _router = createRouter(authCubit: _authCubit, refresh: _refresh);
  }

  @override
  void dispose() {
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: MaterialApp.router(
        title: 'Flowers',
        theme: buildAppTheme(),
        routerConfig: _router,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
