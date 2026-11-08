import 'package:hive/hive.dart';

/// Names and typed accessors for the small Hive boxes used by the app.
class HiveStore {
  HiveStore._();

  static const String settingsBoxName = 'settings';
  static const String cacheBoxName = 'playlist_cache';
  static const String favoritesBoxName = 'favorites';
  static const String epgBoxName = 'epg_cache';

  static const String playlistRawKey = 'raw_m3u';
  static const String playlistParsedKey = 'parsed_json';
  static const String playlistUpdatedAtKey = 'updated_at';
  static const String playlistUrlKey = 'playlist_url';
  static const String playlistVersionKey = 'playlist_version';

  static const String epgDataKey = 'epg_data';
  static const String epgUpdatedAtKey = 'epg_updated_at';

  static Box<String> get settings => Hive.box<String>(settingsBoxName);

  static Box<String> get cache => Hive.box<String>(cacheBoxName);

  static Box<String> get favorites => Hive.box<String>(favoritesBoxName);

  static Box<String> get epg => Hive.box<String>(epgBoxName);

  static Future<void> open() async {
    await Hive.openBox<String>(settingsBoxName);
    await Hive.openBox<String>(cacheBoxName);
    await Hive.openBox<String>(favoritesBoxName);
    await Hive.openBox<String>(epgBoxName);
  }
}
