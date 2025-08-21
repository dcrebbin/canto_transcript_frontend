import 'package:canto_transcripts_frontend/services/logging_service.dart';
import 'package:canto_transcripts_frontend/services/notification_service.dart';
import 'package:get_it/get_it.dart';

final ServiceLocator sl = ServiceLocator._();

class ServiceLocator {
  ServiceLocator._();

  static final GetIt getIt = GetIt.instance;

  T get<T extends Object>() => getIt.get<T>();

  bool isRegistered<T extends Object>() => getIt.isRegistered<T>();

  Future<void> waitUntilReady<T extends Object>() => getIt.isReady<T>();

  Future<void> waitForAllServices() => getIt.allReady();

  void registerSyncServices() {
    getIt.registerLazySingleton<LoggingService>(() => LoggingService());
    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );
  }

  Future<void> setupDependencies() async {
    registerSyncServices();
    await waitForAllServices();
  }
}

extension ServiceLocatorExtensions on ServiceLocator {
  LoggingService get logging => get<LoggingService>();
  NotificationService get notification => get<NotificationService>();
}
