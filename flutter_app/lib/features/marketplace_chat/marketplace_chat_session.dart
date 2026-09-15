import 'data/marketplace_chat_socket_client.dart';
import 'presentation/marketplace_chat_controller.dart';

class MarketplaceChatSession {
  MarketplaceChatSession({
    required this.ownerUserId,
    required this.controller,
    required this.socket,
  });

  final int ownerUserId;
  final MarketplaceChatController controller;
  final MarketplaceChatSocketClient socket;

  bool _started = false;

  bool get hasActiveMediaTransfer => controller.hasActiveMediaTransfer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await controller.start();
  }

  Future<void> resume() => controller.resume();

  Future<void> pause() => controller.stop();

  void updateCurrentUserAvatar(String? avatar) =>
      controller.updateCurrentUserAvatar(avatar);

  Future<void> close({bool clearLocalData = false}) =>
      controller.close(clearLocalData: clearLocalData);
}
