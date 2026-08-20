import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://bbrucbadjiuxjnmrhdvi.supabase.co',
    publishableKey:
    
        'sb_publishable_2mZvTEW9ICYUfjTt1FcuOA_T5zULpRl',
  );

  await NotificationService.initialize();

  runApp(
    const ChemistryCoachingApp(),
  );
}