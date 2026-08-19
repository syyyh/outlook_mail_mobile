import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/mail_controller.dart';
import 'screens/home_screen.dart';
import 'services/account_store.dart';
import 'services/microsoft_mail_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MailController(AccountStore(), MicrosoftMailService());
  await controller.initialize();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(OutlookMailApp(controller: controller));
}

class OutlookMailApp extends StatelessWidget {
  const OutlookMailApp({super.key, required this.controller});

  final MailController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '本地邮箱',
      theme: buildAppTheme(),
      home: HomeScreen(controller: controller),
    );
  }
}
