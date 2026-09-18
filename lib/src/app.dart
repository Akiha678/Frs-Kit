import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_info.dart';
import 'data/greeting_repository.dart';
import 'data/platform_repository.dart';
import 'state/home_binding.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

class FrsKitApp extends StatelessWidget {
  const FrsKitApp({
    this.greetings,
    this.platform,
    this.appId = kAppId,
    super.key,
  });

  final GreetingRepository? greetings;

  final PlatformRepository? platform;

  final String appId;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: frsKitTheme(Brightness.light),
      darkTheme: frsKitTheme(Brightness.dark),
      initialBinding: HomeBinding(
        greetings: greetings,
        platform: platform,
        appId: appId,
      ),
      home: const HomePage(),
    );
  }
}
