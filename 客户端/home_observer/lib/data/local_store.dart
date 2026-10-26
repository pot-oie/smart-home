import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

abstract class LocalStore {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);
}

/// Bounded JSON checkpoint, atomically replaced inside the app documents directory.
class FileStore implements LocalStore {
  FileStore({this.directoryOverride});
  final Directory? directoryOverride;
  Future<File> _file() async {
    final base = directoryOverride ?? await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/home_observer');
    await folder.create(recursive: true);
    return File('${folder.path}/checkpoint.json');
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final parsed = jsonDecode(await file.readAsString());
    if (parsed is! Map<String, dynamic> || parsed['schema'] != 1)
      throw const FormatException('本地记录格式不兼容');
    return parsed;
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final file = await _file();
    final pending = File('${file.path}.pending');
    await pending.writeAsString(jsonEncode(data), flush: true);
    await pending.rename(file.path);
  }
}

class MemoryStore implements LocalStore {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> load() async =>
      data == null ? null : jsonDecode(jsonEncode(data));
  @override
  Future<void> save(Map<String, dynamic> value) async {
    data = jsonDecode(jsonEncode(value));
  }
}
