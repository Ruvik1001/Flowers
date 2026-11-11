import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Flowers'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход для сотрудников'**
  String get loginTitle;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get signOut;

  /// No description provided for @catalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get catalog;

  /// No description provided for @procurement.
  ///
  /// In ru, this message translates to:
  /// **'Закупки'**
  String get procurement;

  /// No description provided for @inventory.
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get inventory;

  /// No description provided for @sales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get sales;

  /// No description provided for @cashier.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get cashier;

  /// No description provided for @assembly.
  ///
  /// In ru, this message translates to:
  /// **'Сборка'**
  String get assembly;

  /// No description provided for @analytics.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get analytics;

  /// No description provided for @audit.
  ///
  /// In ru, this message translates to:
  /// **'Аудит'**
  String get audit;

  /// No description provided for @admin.
  ///
  /// In ru, this message translates to:
  /// **'Админ'**
  String get admin;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @create.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get errorGeneric;

  /// No description provided for @noData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noData;

  /// No description provided for @products.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get products;

  /// No description provided for @recipes.
  ///
  /// In ru, this message translates to:
  /// **'Рецепты'**
  String get recipes;

  /// No description provided for @suppliers.
  ///
  /// In ru, this message translates to:
  /// **'Поставщики'**
  String get suppliers;

  /// No description provided for @supplies.
  ///
  /// In ru, this message translates to:
  /// **'Поставки'**
  String get supplies;

  /// No description provided for @lots.
  ///
  /// In ru, this message translates to:
  /// **'Партии'**
  String get lots;

  /// No description provided for @expired.
  ///
  /// In ru, this message translates to:
  /// **'Просрочка'**
  String get expired;

  /// No description provided for @writeOffs.
  ///
  /// In ru, this message translates to:
  /// **'Списания'**
  String get writeOffs;

  /// No description provided for @counts.
  ///
  /// In ru, this message translates to:
  /// **'Инвентаризация'**
  String get counts;

  /// No description provided for @shifts.
  ///
  /// In ru, this message translates to:
  /// **'Смены'**
  String get shifts;

  /// No description provided for @assemblies.
  ///
  /// In ru, this message translates to:
  /// **'Сборки'**
  String get assemblies;

  /// No description provided for @users.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get users;

  /// No description provided for @roles.
  ///
  /// In ru, this message translates to:
  /// **'Роли'**
  String get roles;

  /// No description provided for @reports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get reports;

  /// No description provided for @openShift.
  ///
  /// In ru, this message translates to:
  /// **'Открыть смену'**
  String get openShift;

  /// No description provided for @closeShift.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть смену'**
  String get closeShift;

  /// No description provided for @completeSale.
  ///
  /// In ru, this message translates to:
  /// **'Оформить продажу'**
  String get completeSale;

  /// No description provided for @archive.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать'**
  String get archive;

  /// No description provided for @accept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get accept;

  /// No description provided for @uploadPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить фото'**
  String get uploadPhoto;

  /// No description provided for @requiredField.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get requiredField;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
