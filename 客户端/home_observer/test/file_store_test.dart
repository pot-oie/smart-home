import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/data/local_store.dart';

void main() {
  test('真实文件检查点替换后可重新读取，临时文件不残留', () async {
    final directory = await Directory.systemTemp.createTemp(
      'home-observer-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileStore(directoryOverride: directory);
    expect(await store.load(), isNull);
    await store.save({
      'schema': 1,
      'config': {'tHigh': 30},
      'events': [],
    });
    await store.save({
      'schema': 1,
      'config': {'tHigh': 32},
      'events': [
        {'eventId': 'e1'},
      ],
    });
    final reopened = FileStore(directoryOverride: directory);
    final result = await reopened.load();
    expect(result!['config']['tHigh'], 32);
    expect(result['events'].length, 1);
    expect(
      File(
        '${directory.path}/home_observer/checkpoint.json.pending',
      ).existsSync(),
      isFalse,
    );
  });
  test('损坏存储报告错误，不自动覆盖用户记录', () async {
    final directory = await Directory.systemTemp.createTemp(
      'home-observer-corrupt-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final folder = Directory('${directory.path}/home_observer');
    await folder.create();
    final file = File('${folder.path}/checkpoint.json');
    await file.writeAsString('corrupt');
    final store = FileStore(directoryOverride: directory);
    await expectLater(store.load(), throwsFormatException);
    expect(await file.readAsString(), 'corrupt');
  });
}
