import 'dart:io';

import 'package:canto_transcripts_frontend/utilities/service_locator.dart';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';

enum LogLevel { info, error, off }

@lazySingleton
class LoggingService {
  final log = Logger('LoggingService');
  String loggingEndpoint = "api/logging";

  List<String> logs = ["Starting logging service"];
  Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('langpal.cn');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  Future<void> logEvent({
    required String eventName,
    Map<String, Object>? properties,
  }) async {
    log.info("Logging event: $eventName");
    try {
      log.info("Event logged: $eventName");
    } catch (e) {
      log.severe(e, StackTrace.current);
    }
  }

  Future<void> logMessage(
    Object message, {
    bool showToast = true,
    bool isError = false,
    bool sendToServer = false,
  }) async {
    try {
      logs.add(message.toString());
      if (showToast) {
        if (isError) {
          sl.notification.showError(message.toString());
        } else {
          sl.notification.showSuccess(message.toString());
        }
      }

      log.info(message);
    } catch (e) {
      log.severe(e, StackTrace.current);
    }
  }

  Future<void> logError(
    Object error,
    StackTrace stackTrace, {
    bool showToast = true,
  }) async {
    try {
      logs.add(error.toString());
      if (showToast) {
        sl.notification.showError(error.toString());
      }
      log.severe(error, stackTrace);
    } catch (e) {
      log.severe(e, stackTrace);
    }
  }
}
