import 'data_service.dart';
import 'store.dart';

/// Fetches a day from the server and stores it in the on-device cache.
Future<String> syncDay(TaskStore store, String date) async {
  final service = DataService(baseUrl: store.serverUrl, token: store.mobileToken);
  try {
    final day = await service.fetchDay(date);
    await store.cacheDay(day);
    return 'Synced $date from the server.';
  } on DataServiceException catch (error) {
    return error.message;
  } catch (error) {
    return 'Sync failed: $error';
  } finally {
    service.close();
  }
}

/// Fetches today if present, otherwise the most recent available day.
Future<String> syncLatest(TaskStore store) async {
  final service = DataService(baseUrl: store.serverUrl, token: store.mobileToken);
  try {
    final dates = await service.fetchDates();
    if (dates.isEmpty) return 'No daily records on the server.';
    final today = todayKey();
    final target = dates.contains(today) ? today : dates.last;
    final day = await service.fetchDay(target);
    await store.cacheDay(day);
    return 'Synced $target from the server.';
  } on DataServiceException catch (error) {
    return error.message;
  } catch (error) {
    return 'Sync failed: $error';
  } finally {
    service.close();
  }
}
