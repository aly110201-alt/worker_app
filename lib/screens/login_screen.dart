import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'contractor_dashboard.dart';
import 'worker_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'worker'; // الافتراضي عامل لتسهيل الاستخدام

  // إيميل وكلمة مرور المقاول الرسمية المحددة
  final String contractorMasterEmail = "elhlalgrup@s.com";
  final String contractorMasterPassword = "sleman@@";

  // كلمة المرور الموحدة لجميع العمال
  final String workerDefaultPassword = "elhlal1234@";

  Future<void> _login() async {
    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال البريد الإلكتروني وكلمة المرور'),
        ),
      );
      return;
    }

    // إظهار مؤشر تحميل أثناء التحقق
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_selectedRole == 'contractor') {
        // التحقق من إيميل وكلمة مرور المقاول بدقة
        if ((email == contractorMasterEmail ||
                email.contains('admin') ||
                email.contains('contractor')) &&
            password == contractorMasterPassword) {
          Navigator.pop(context); // إغلاق التحميل
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ContractorDashboard(),
            ),
          );
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'عذراً، البريد الإلكتروني أو كلمة المرور الخاصة بالمقاول غير صحيحة',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // التحقق من كلمة مرور العمال الموحدة أولاً
        if (password != workerDefaultPassword) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('عذراً، كلمة مرور العامل غير صحيحة'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // فحص حالة العامل أو إرسال طلب تسجيل جديد تلقائياً للمقاول
        String workerStatus = await DatabaseService.checkOrRegisterWorker(
          email,
        );

        Navigator.pop(context); // إغلاق التحميل

        if (workerStatus == 'approved') {
          // العامل مفعل ومقبول من المقاول، يتم دخوله مباشرة
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerScreen(workerEmail: email),
            ),
          );
        } else {
          // العامل بانتظار موافقة المقاول وتم إرسال الطلب بنجاح
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم إرسال طلب تسجيل الدخول إلى المقاول بنجاح. يجدر الانتظار لحين الموافقة.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تسجيل الدخول: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_person,
                    size: 64,
                    color: Color(0xFF1E3A8A),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تسجيل الدخول للنظام',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // حقل البريد الإلكتروني
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني المخصص',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // حقل كلمة المرور
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // اختيار نوع الحساب
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'حدد نوع الحساب',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'contractor',
                        child: Text('مقاول (إدارة وعمال)'),
                      ),
                      DropdownMenuItem(
                        value: 'worker',
                        child: Text('عامل (تسجيل حضور وموقع)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // زر الدخول
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _login,
                      child: const Text(
                        'دخول',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
