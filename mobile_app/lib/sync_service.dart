import 'activity_log.dart';
import 'data_service.dart';
import 'store.dart';

/// Fetches a day from the server and stores it in the on-device cache.
Future<String> syncDay(TaskStore store, String date) async {
  await activityLog.add('sync', 'Fetching $date from the server.');
  final service = DataService(baseUrl: store.serverUrl, token: store.mobileToken);
  try {
    final day = await service.fetchDay(date);
    await store.cacheDay(day);
    await activityLog.add('sync', 'Saved $date (${day.tasks.length} tasks) to the phone cache.');
    return 'Synced $date from the server.';
  } on DataServiceException catch (error) {
    await activityLog.add('sync', 'Failed for $date: ${error.message}');
    return error.message;
  } catch (error) {
    await activityLog.add('sync', 'Failed for $date: $error');
    return 'Sync failed: $error';
  } finally {
    service.close();
  }
}

/// Fetches today if present, otherwise the most recent available day.
Future<String> syncLatest(TaskStore store) async {
  await activityLog.add('sync', 'Sync started.');
  final service = DataService(baseUrl: store.serverUrl, token: store.mobileToken);
  try {
    final dates = await service.fetchDates();
    if (dates.isEmpty) {
      await activityLog.add('sync', 'No daily records on the server.');
      return 'No daily records on the server.';
    }
    final today = todayKey();
    final target = dates.contains(today) ? today : dates.last;
    final day = await service.fetchDay(target);
    await store.cacheDay(day);
    await activityLog.add('sync', 'Synced $target (${day.tasks.length} tasks).');
    return 'Synced $target from the server.';
  } on DataServiceException catch (error) {
    await activityLog.add('sync', 'Sync failed: ${error.message}');
    return error.message;
  } catch (error) {
    await activityLog.add('sync', 'Sync failed: $error');
    return 'Sync failed: $error';
  } finally {
    service.close();
  }
}
