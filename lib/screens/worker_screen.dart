import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // مكتبة جلب إحداثيات الـ GPS

import 'dart:typed_data'; // لدعم بايتات الصور على الويب والهواتف

import '../models/attendance_model.dart';
import '../services/database_service.dart';

class WorkerScreen extends StatefulWidget {
  final String workerEmail;
  const WorkerScreen({super.key, required this.workerEmail});

  @override
  State<WorkerScreen> createState() => _WorkerScreenState();
}

class _WorkerScreenState extends State<WorkerScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  Uint8List?
  _webImageBytes; // متغير لتخزين بايتات الصورة الملتقطة المتوافقة مع الويب

  // دالة فتح الكاميرا لتصوير العمل اليومي
  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      var bytes = await image.readAsBytes();
      setState(() {
        _webImageBytes = bytes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التقاط صورة العمل بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // دالة تسجيل الحضور الصباحي مع جلب الإحداثيات الحالية للموقع والصورة
  Future<void> _handleAttendance() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تفعيل خدمة الموقع (GPS) في جهازك'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('صلاحية الموقع مرفوضة، لا يمكن تسجيل الحضور'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String coordinates = '${position.latitude}, ${position.longitude}';

      // رفع الصورة الحقيقية إذا وجدت، أو حفظ none
      String imagePath = 'none';
      if (_webImageBytes != null) {
        String? uploadedUrl = await DatabaseService.uploadImageBytes(
          _webImageBytes!,
        );
        if (uploadedUrl != null) {
          imagePath = uploadedUrl;
        }
      }

      final recordId =
          '${widget.workerEmail}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      final record = AttendanceRecord(
        id: recordId,
        workerId: widget.workerEmail,
        dateTime: DateTime.now(),
        workerName: widget.workerEmail,
        siteName: 'الموقع الرئيسي',
        locationCoordinates: coordinates,
        selfieImagePath: imagePath, // حفظ رابط الصورة الحقيقي هنا
        dailyRate: 0.0,
      );

      final errorMsg = await DatabaseService.addAttendance(record);
      setState(() => _isLoading = false);

      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تسجيل الحضور الصباحي وتثبيت موقع العمل والصورة بنجاح!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _webImageBytes = null);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديد الموقع الجغرافي: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة تسجيل الانصراف الرسمي
  Future<void> _handleCheckout() async {
    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String currentCoordinates = '${position.latitude}, ${position.longitude}';

      final errorMsg = await DatabaseService.checkoutAttendance(
        widget.workerEmail,
        currentCoordinates,
      );
      setState(() => _isLoading = false);

      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الانصراف الرسمي بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديد الموقع الحالي للانصراف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة تسجيل الوقت الإضافي
  Future<void> _handleOvertime() async {
    setState(() => _isLoading = true);
    final errorMsg = await DatabaseService.recordOvertime(widget.workerEmail);
    setState(() => _isLoading = false);

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم احتساب وإضافة ساعات العمل الإضافي تلقائياً!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // دالة إرسال التقرير الشامل والملاحظات مع رفع الصورة للسيرفر
  Future<void> _submitReport() async {
    if (_notesController.text.trim().isEmpty && _webImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء كتابة ملاحظات العمل أو التقاط صورة إنجاز أولاً',
          ),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    String imagePath = 'none';
    if (_webImageBytes != null) {
      // رفع الصورة وحفظ الرابط الحقيقي الناتج من Firebase Storage
      String? uploadedUrl = await DatabaseService.uploadImageBytes(
        _webImageBytes!,
      );
      if (uploadedUrl != null) {
        imagePath = uploadedUrl;
      }
    }

    bool success = await DatabaseService.submitWorkReport(
      workerId: widget.workerEmail,
      imagePath: imagePath,
      notes: _notesController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال تقرير العمل والصورة بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      _notesController.clear();
      setState(() => _webImageBytes = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على سجل حضور لهذا اليوم.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة العامل - الحضور والمهام'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'مرحباً بك: ${widget.workerEmail}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- قسم أزرار الحضور والانصراف والكاميرا ---
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // زر الحضور الصباحي
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _handleAttendance,
                            icon: const Icon(Icons.login),
                            label: const Text(
                              'تأكيد تسجيل الحضور (الصباح)',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // زر الانصراف الرسمي
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _handleCheckout,
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'تسجيل الانصراف الرسمي (5:00 م)',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // زر الوقت الإضافي
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _handleOvertime,
                            icon: const Icon(Icons.more_time),
                            label: const Text(
                              'تسجيل/إنهاء الوقت الإضافي (حساب تلقائي)',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // زر فتح الكاميرا لتصوير العمل اليومي
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E3A8A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: Color(0xFF1E3A8A),
                                width: 1.5,
                              ),
                            ),
                            onPressed: _pickImageFromCamera,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text(
                              'تصوير إنجاز العمل اليومي (فتح الكاميرا)',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // معاينة الصورة المتوافقة مع الويب باستخدام الذاكرة
                          if (_webImageBytes != null)
                            Container(
                              height: 150,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _webImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                          // حقل الملاحظات
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText:
                                  'اكتب ملاحظاتك أو تفاصيل ما أنجزته اليوم...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // زر إرسال التقرير الشامل
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _submitReport,
                            icon: const Icon(Icons.send),
                            label: const Text(
                              'إرسال تقرير الإنجاز اليومي',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- قسم المهام المسندة من المقاول ---
                  const Text(
                    'المهام المطلوبة منك من المقاول',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<TaskModel>>(
                    stream: DatabaseService.getWorkerTasks(widget.workerEmail),
                    builder: (context, snapshot) {
                      final tasks = snapshot.data ?? [];
                      if (tasks.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('لا توجد مهام مسندة إليك حالياً.'),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(
                                'الموقع: ${task.siteName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'المهمة: ${task.taskDescription}\nالتاريخ: ${task.date}',
                              ),
                              isThreeLine: true,
                              trailing: Checkbox(
                                value: task.isCompleted,
                                onChanged: (val) async {
                                  task.isCompleted = val ?? false;
                                  await DatabaseService.assignTask(task);
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- قسم السُلَف المالية المستقلة ---
                  const Text(
                    'سجل السُلَف المالية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<AdvanceModel>>(
                    stream: DatabaseService.getWorkerAdvances(
                      widget.workerEmail,
                    ),
                    builder: (context, snapshot) {
                      final advances = snapshot.data ?? [];
                      if (advances.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('لا توجد سلف مسجلة باسمك.'),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: advances.length,
                        itemBuilder: (context, index) {
                          final adv = advances[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(
                                Icons.money,
                                color: Colors.orange,
                              ),
                              title: Text(
                                'مبلغ السلفة: ${adv.amount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              subtitle: Text('التاريخ والوقت: ${adv.dateTime}'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
