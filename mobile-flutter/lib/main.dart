import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EduApp(services: AppServices.production()));
}
