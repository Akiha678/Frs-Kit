import 'package:get/get.dart';

import '../data/greeting_repository.dart';
import '../data/platform_repository.dart';
import 'home_state.dart';

class HomeBinding extends Bindings {
  HomeBinding({this.greetings, this.platform, this.appId});

  final GreetingRepository? greetings;

  final PlatformRepository? platform;

  final String? appId;

  @override
  void dependencies() {
    Get.lazyPut<GreetingRepository>(
      () => greetings ?? const GreetingRepository(),
      fenix: true,
    );
    Get.lazyPut<PlatformRepository>(
      () => platform ?? const PlatformRepository(),
      fenix: true,
    );
    Get.lazyPut<HomeState>(
      () => appId == null ? HomeState() : HomeState(appId: appId!),
      fenix: true,
    );
  }
}
