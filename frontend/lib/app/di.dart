import 'package:flowers/core/auth/token_storage.dart';
import 'package:flowers/core/config/app_config.dart';
import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/features/admin/data/admin_repository.dart';
import 'package:flowers/features/analytics/data/analytics_repository.dart';
import 'package:flowers/features/assembly/data/assembly_repository.dart';
import 'package:flowers/features/audit/data/audit_repository.dart';
import 'package:flowers/features/auth/data/auth_repository.dart';
import 'package:flowers/features/cashier/data/cashier_repository.dart';
import 'package:flowers/features/catalog/data/catalog_repository.dart';
import 'package:flowers/features/files/data/files_repository.dart';
import 'package:flowers/features/inventory/data/inventory_repository.dart';
import 'package:flowers/features/procurement/data/procurement_repository.dart';
import 'package:flowers/features/sales/data/sales_repository.dart';

/// Lightweight service locator (no get_it).
class Di {
  Di._();
  static final Di I = Di._();

  late final AppConfig config;
  late final TokenStorage tokenStorage;
  late final ApiClient api;
  late final AuthRepository auth;
  late final CatalogRepository catalog;
  late final ProcurementRepository procurement;
  late final InventoryRepository inventory;
  late final SalesRepository sales;
  late final CashierRepository cashier;
  late final AssemblyRepository assembly;
  late final FilesRepository files;
  late final AnalyticsRepository analytics;
  late final AuditRepository audit;
  late final AdminRepository admin;

  Future<void> configure({AppConfig? appConfig}) async {
    config = appConfig ?? AppConfig.fromEnvironment();
    tokenStorage = TokenStorage();

    late final AuthRepository authRepository;
    api = ApiClient(
      config: config,
      tokenStorage: tokenStorage,
      onRefresh: () => authRepository.refreshSession(),
    );
    authRepository = AuthRepository(api: api, tokenStorage: tokenStorage);
    auth = authRepository;

    catalog = CatalogRepository(api: api);
    procurement = ProcurementRepository(api: api);
    inventory = InventoryRepository(api: api);
    sales = SalesRepository(api: api);
    cashier = CashierRepository(api: api);
    assembly = AssemblyRepository(api: api);
    files = FilesRepository(api: api);
    analytics = AnalyticsRepository(api: api);
    audit = AuditRepository(api: api);
    admin = AdminRepository(api: api);
  }
}
