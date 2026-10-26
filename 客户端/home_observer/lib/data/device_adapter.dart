import '../domain/models.dart';

/// No physical transport is selected yet. BLE/Wi-Fi adapters implement this contract.
abstract class DeviceAdapter {
  String get sourceName;
  bool get isSimulation;
  bool get connected;
  Stream<DeviceMessage> get messages;
  void start();
  Future<void> send(DeviceRequest request);
  void receipt(String eventId, int revision);
  Future<void> close();
}
