/// Russian display labels for API enums / codes shown in the UI.
class Labels {
  const Labels._();

  static String orDash(Object? value) {
    if (value == null) return '—';
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return '—';
    return s;
  }

  static String productKind(String kind) => switch (kind) {
        'flower' => 'Цветок',
        'material' => 'Материал',
        'bouquet' => 'Букет',
        _ => kind.isEmpty ? '—' : kind,
      };

  static String assemblyKind(String kind) => switch (kind) {
        'free' => 'Свободная',
        'recipe' => 'По рецепту',
        _ => kind.isEmpty ? '—' : kind,
      };

  static String paymentMethod(String method) => switch (method) {
        'cash' => 'Наличные',
        'card' => 'Карта',
        'transfer' => 'Перевод',
        _ => method.isEmpty ? '—' : method,
      };

  static String refundKind(String kind) => switch (kind) {
        'money_only' => 'Только деньги',
        'stock_back' => 'На склад',
        'defect_write_off' => 'Брак',
        _ => kind.isEmpty ? '—' : kind,
      };

  static String report(String name) => switch (name) {
        'revenue-by-day' => 'Выручка по дням',
        'revenue-by-shift' => 'Выручка по сменам',
        'sales-by-product' => 'Продажи по товарам',
        'stock-turnover' => 'Оборачиваемость склада',
        'margin' => 'Маржа',
        'cash-gaps' => 'Кассовые расхождения',
        'write-offs' => 'Списания',
        _ => name,
      };

  static String auditEvent(String name) => switch (name) {
        'SaleCompleted' => 'Продажа завершена',
        'ShiftClosed' => 'Смена закрыта',
        'SupplyAccepted' => 'Поставка принята',
        'UserRoleChanged' => 'Роли пользователя изменены',
        'AssemblyCompleted' => 'Сборка завершена',
        'StockChanged' => 'Остаток изменён',
        'WriteOffCompleted' => 'Списание выполнено',
        _ => name.isEmpty ? '—' : name,
      };

  static const knownAuditEvents = <String>[
    'SaleCompleted',
    'ShiftClosed',
    'SupplyAccepted',
    'UserRoleChanged',
    'AssemblyCompleted',
    'StockChanged',
    'WriteOffCompleted',
  ];

  static String entityType(String type) => switch (type) {
        'sale' => 'продажа',
        'product' => 'товар',
        'shift' => 'смена',
        'supply' => 'поставка',
        'assembly' => 'сборка',
        'user' => 'пользователь',
        'lot' => 'партия',
        _ => type.isEmpty ? '—' : type,
      };

  static const knownPermissions = <String>[
    '*',
    'sales.read',
    'sales.write',
    'cashier.read',
    'cashier.write',
    'catalog.read',
    'catalog.write',
    'inventory.read',
    'inventory.write',
    'procurement.read',
    'procurement.write',
    'assembly.read',
    'assembly.write',
    'analytics.read',
    'audit.read',
    'identity.users.write',
    'files.write',
    'files.read',
  ];

  static String permission(String code) => switch (code) {
        '*' => 'Все права',
        'sales.read' => 'Чтение продаж',
        'sales.write' => 'Запись продаж',
        'cashier.read' => 'Чтение кассы',
        'cashier.write' => 'Запись кассы',
        'catalog.read' => 'Чтение каталога',
        'catalog.write' => 'Запись каталога',
        'inventory.read' => 'Чтение склада',
        'inventory.write' => 'Запись склада',
        'procurement.read' => 'Чтение закупок',
        'procurement.write' => 'Запись закупок',
        'assembly.read' => 'Чтение сборок',
        'assembly.write' => 'Запись сборок',
        'analytics.read' => 'Чтение аналитики',
        'audit.read' => 'Чтение аудита',
        'identity.users.write' => 'Создание пользователей',
        'files.write' => 'Загрузка файлов',
        'files.read' => 'Чтение файлов',
        _ => code,
      };

  static String permissionsList(Iterable<String> codes) =>
      codes.map(permission).join(', ');

  static String reportKey(String key) => switch (key) {
        'key' => 'Ключ',
        'value' => 'Значение',
        'product_id' => 'Товар',
        'quantity' => 'Количество',
        'revenue' => 'Выручка',
        'cost' => 'Себестоимость',
        'margin' => 'Маржа',
        'movement' => 'Движение',
        'turnover' => 'Оборачиваемость',
        'status' => 'Статус',
        'items' => 'Позиции',
        _ => key,
      };

  static String errorCode(String? code, String fallback) {
    if (code == null || code.isEmpty) return fallback;
    return switch (code) {
      'invalid_credentials' => 'Неверный email или пароль',
      'missing_token' => 'Требуется авторизация',
      'invalid_token' => 'Сессия истекла или токен недействителен',
      'invalid_token_type' => 'Неверный тип токена',
      'forbidden' => 'Недостаточно прав',
      'object_forbidden' => 'Нет доступа к объекту',
      'rate_limited' => 'Слишком много запросов',
      'upstream_unavailable' => 'Сервис временно недоступен',
      'internal_error' => 'Внутренняя ошибка сервера',
      'product_not_found' => 'Товар не найден',
      'recipe_not_found' => 'Рецепт не найден',
      'supplier_not_found' => 'Поставщик не найден',
      'supply_not_found' => 'Поставка не найдена',
      'line_not_found' => 'Строка поставки не найдена',
      'sale_not_found' => 'Продажа не найдена',
      'shift_not_found' => 'Смена не найдена',
      'shift_already_open' => 'У кассира уже есть открытая смена',
      'shift_closed' => 'Смена уже закрыта',
      'insufficient_stock' => 'Недостаточно остатка на складе',
      'payment_mismatch' => 'Сумма оплаты не совпадает с итогом',
      'invalid_sale' => 'Некорректная продажа',
      'invalid_refund' => 'Некорректный возврат',
      'photos_required' => 'Нужно приложить от 1 до 10 фото',
      'email_taken' => 'Эл. почта уже зарегистрирована',
      'role_exists' => 'Роль уже существует',
      'role_not_found' => 'Роль не найдена',
      'file_too_large' => 'Файл больше 5 МБ',
      'invalid_file_type' => 'Допустимы только JPEG, PNG и WebP',
      'file_not_found' => 'Файл не найден',
      'report_not_found' => 'Отчёт не найден',
      'validation_error' => 'Ошибка валидации',
      'timeout' => 'Таймаут запроса',
      'connection_error' => 'Нет связи с сервером',
      'not_ready' => 'Сервис не готов',
      _ => fallback,
    };
  }

  static const dateHint = 'ГГГГ-ММ-ДД';
}
