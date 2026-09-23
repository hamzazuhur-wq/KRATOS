// Wave 18: KRATOS Entrypoint.
// Initializes the local database, auth service, and boots the KratosApp shell.

import 'package:flutter/material.dart';
import 'app/kratos_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KratosApp());
}
