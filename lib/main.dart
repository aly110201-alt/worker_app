import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ربط التطبيق بقاعدة البيانات السحابية
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBkjboAiAfyD5-hUOD22Gbr5Xtz7-WhTRA",
      appId: "1:254644972863:web:3580f3618915f8e7ab778a",
      messagingSenderId: "254644972863",
      projectId: "workerattendanceapp-43433",
      authDomain: "workerattendanceapp-43433.firebaseapp.com",
      storageBucket: "workerattendanceapp-43433.firebasestorage.app",
    ),
  );

  runApp(const WorkerAttendanceApp());
}

class WorkerAttendanceApp extends StatelessWidget {
  const WorkerAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        title: 'نظام حضور العمال والمقاول',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
