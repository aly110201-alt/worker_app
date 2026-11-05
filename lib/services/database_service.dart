import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'dart:typed_data';

import '../models/attendance_model.dart';

// --- نماذج البيانات المساعدة للمهام والسلاف ---
class TaskModel {
  final String id;
  final String workerEmail;
  final String siteName;
  final String taskDescription;
  final String date;
  bool isCompleted;

  TaskModel({
    required this.id,
    required this.workerEmail,
    required this.siteName,
    required this.taskDescription,
    required this.date,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerEmail': workerEmail,
      'siteName': siteName,
      'taskDescription': taskDescription,
      'date': date,
      'isCompleted': isCompleted,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String docId) {
    return TaskModel(
      id: docId,
      workerEmail: map['workerEmail'] ?? '',
      siteName: map['siteName'] ?? '',
      taskDescription: map['taskDescription'] ?? '',
      date: map['date'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class AdvanceModel {
  final String id;
  final String workerEmail;
  final double amount;
  final String dateTime;

  AdvanceModel({
    required this.id,
    required this.workerEmail,
    required this.amount,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerEmail': workerEmail,
      'amount': amount,
      'dateTime': dateTime,
    };
  }

  factory AdvanceModel.fromMap(Map<String, dynamic> map, String docId) {
    return AdvanceModel(
      id: docId,
      workerEmail: map['workerEmail'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      dateTime: map['dateTime'] ?? '',
    );
  }
}

class DatabaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- دوال رفع الصور (Storage) ---

  // دالة رفع بايتات الصورة إلى Firebase Storage وإرجاع رابط الـ URL
  static Future<String?> uploadImageBytes(Uint8List imageBytes) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'attendance_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // رفع البيانات مباشرة بدون الحاجة لمسار ملف (متوافق تماماً مع الويب والهاتف)
      UploadTask uploadTask = storageRef.putData(imageBytes);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }

  // --- العمال (Workers) ---

  // تهيئة كافة إيميلات العمال الـ 14 الرسمية في النظام سحابياً
  static initializeDefaultWorkers() async {
    List<String> workerEmails = [
      'elhlalgrup.projects.a@elhalal.com',
      'elhlalgrup.projects.b@elhalal.com',
      'elhlalgrup.projects.c@elhalal.com',
      'elhlalgrup.projects.d@elhalal.com',
      'elhlalgrup.projects.e@elhalal.com',
      'elhlalgrup.projects.f@elhalal.com',
      'elhlalgrup.projects.g@elhalal.com',
      'elhlalgrup.projects.h@elhalal.com',
      'elhlalgrup.projects.i@elhalal.com',
      'elhlalgrup.projects.j@elhalal.com',
      'elhlalgrup.projects.k@elhalal.com',
      'elhlalgrup.projects.l@elhalal.com',
      'elhlalgrup.projects.o@elhalal.com',
      'elhlalgrup.projects.n@elhalal.com',
      'elhlalgrup.projects.m@elhalal.com',
      'elhlalgrup.projects.p@elhalal.com',
      'elhlalgrup.projects.q@elhalal.com',
      'elhlalgrup.projects.r@elhalal.com',
      'elhlalgrup.projects.s@elhalal.com',
      'elhlalgrup.projects.t@elhalal.com',
      'elhlalgrup.projects.u@elhalal.com',
      'elhlalgrup.projects.v@elhalal.com',
      'elhlalgrup.projects.w@elhalal.com',
      'elhlalgrup.projects.x@elhalal.com',
      'elhlalgrup.projects.y@elhalal.com',
      'elhlalgrup.projects.z@elhalal.com',
    ];

    for (int i = 0; i < workerEmails.length; i++) {
      String workerEmail = workerEmails[i];
      final docRef = _db.collection('workers').doc(workerEmail);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'id': workerEmail,
          'name': 'عامل مشروع ${i + 1}',
          'siteName': 'الموقع العام',
          'dailyRate': 50.0,
          'advancePayment': 0.0,
          'isApproved': false, // بانتظار موافقة المقاول عند الدخول لأول مرة
          'isActive': false,
        });
      }
    }
  }

  // فحص العامل عند تسجيل الدخول أو إنشاء طلب تسجيل جديد تلقائياً للمقاول
  static Future<String> checkOrRegisterWorker(String email) async {
    final docRef = _db.collection('workers').doc(email);
    final doc = await docRef.get();

    if (!doc.exists) {
      // إنشاء طلب جديد بحالة معلق (بانتظار موافقة المقاول)
      await docRef.set({
        'id': email,
        'name': email.split('@')[0],
        'siteName': 'الموقع العام',
        'dailyRate': 50.0,
        'advancePayment': 0.0,
        'isApproved': false, // بانتظار موافقة المقاول
        'isActive': false,
      });
      return 'pending';
    }

    final data = doc.data();
    bool isApproved = data?['isApproved'] ?? false;

    return isApproved ? 'approved' : 'pending';
  }

  static getWorkerStatus(String email) async {
    final doc = await _db.collection('workers').doc(email).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // الموافقة على العامل أو سحب الصلاحية منه (طرد / إيقاف)
  static approveWorker(String email, bool isApproved) async {
    await _db.collection('workers').doc(email).update({
      'isApproved': isApproved,
      'isActive': isApproved,
    });
  }

  static addWorker(WorkerModel worker) async {
    await _db.collection('workers').doc(worker.id).set({
      ...worker.toMap(),
      'isApproved': true,
      'isActive': true,
    });
  }

  static updateWorker(WorkerModel worker) async {
    await _db.collection('workers').doc(worker.id).update(worker.toMap());
  }

  static deleteWorker(String workerId) async {
    await _db.collection('workers').doc(workerId).delete();
  }

  static isWorkerActive(String workerEmail) async {
    final doc = await _db.collection('workers').doc(workerEmail).get();
    if (!doc.exists) return false;
    final data = doc.data();
    return data != null && (data['isApproved'] ?? false) == true;
  }

  static Stream<List<WorkerModel>> getWorkersStream() {
    return _db.collection('workers').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => WorkerModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // --- مواقع العمل (Sites) ---

  static addSite(String siteName) async {
    await _db.collection('sites').add({'name': siteName});
  }

  static Stream<List<String>> getSitesStream() {
    return _db.collection('sites').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc['name'].toString()).toList();
    });
  }

  static deleteSite(String siteName) async {
    final query = await _db
        .collection('sites')
        .where('name', isEqualTo: siteName)
        .get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }

  // --- إسناد وحذف المهام (Tasks) ---

  static assignTask(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).set(task.toMap());
  }

  // دالة حذف المهمة المطلوبة
  static deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  static Stream<List<TaskModel>> getWorkerTasks(String workerEmail) {
    return _db
        .collection('tasks')
        .where('workerEmail', isEqualTo: workerEmail)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // --- إدارة السلاف (Advances) ---

  static addAdvance(AdvanceModel advance) async {
    await _db.collection('advances').add(advance.toMap());
  }

  static Stream<List<AdvanceModel>> getWorkerAdvances(String workerEmail) {
    return _db
        .collection('advances')
        .where('workerEmail', isEqualTo: workerEmail)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdvanceModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // --- تسكير الحساب (Settlement) ---

  static settleAccount(String workerEmail, double finalAmount) async {
    final settlementId =
        '${workerEmail}_settlement_${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('settlements').doc(settlementId).set({
      'workerEmail': workerEmail,
      'finalAmount': finalAmount,
      'dateTime': DateTime.now().toIso8601String(),
    });
  }

  // --- الحضور والانصراف والتقارير ---

  static addAttendance(AttendanceRecord record) async {
    final now = DateTime.now();

    if (now.hour > 8 || (now.hour == 8 && now.minute > 15)) {
      return 'عذراً، انتهى الوقت المسموح لتسجيل الحضور الصباحي (الحد الأقصى 8:15 صباحاً).';
    }

    await _db.collection('attendance').doc(record.id).set(record.toMap());
    return null;
  }

  // دالة تسجيل الانصراف مع التحقق من النطاق الجغرافي (بقطر 400 متر)
  static Future<String?> checkoutAttendance(
    String workerId,
    String currentCoordinates,
  ) async {
    final now = DateTime.now();

    if (now.hour < 16 || (now.hour == 16 && now.minute < 45)) {
      return 'عذراً، لا يمكنك تسجيل الانصراف الرسمي قبل الساعة 4:45 مساءً.';
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final querySnapshot = await _db
        .collection('attendance')
        .where('workerId', isEqualTo: workerId)
        .get();

    bool foundRecord = false;
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final dateTimeStr = data['dateTime'] ?? '';

      if (dateTimeStr.startsWith(todayStr)) {
        // --- قائمة الإيميلات المستثناة (تستطيع الانصراف من أي مكان) ---
        List<String> exemptedEmails = [
          'elhlalgrup.projects.a@elhalal.com',
          'elhlalgrup.projects.b@elhalal.com',
        ];

        // التحقق مما إذا كان العامل غير موجود في قائمة الاستثناءات
        if (!exemptedEmails.contains(workerId)) {
          final morningCoordinates = data['locationCoordinates'] ?? '0.0, 0.0';

          if (morningCoordinates != '0.0, 0.0') {
            try {
              List<String> morningParts = morningCoordinates.split(',');
              double morningLat = double.parse(morningParts[0].trim());
              double morningLng = double.parse(morningParts[1].trim());

              List<String> currentParts = currentCoordinates.split(',');
              double currentLat = double.parse(currentParts[0].trim());
              double currentLng = double.parse(currentParts[1].trim());

              // حساب المسافة بالأمتار بين نقطة الصباح ونقطة الانصراف
              double distanceInMeters = Geolocator.distanceBetween(
                morningLat,
                morningLng,
                currentLat,
                currentLng,
              );

              // السماح بالانصراف إذا كانت المسافة ضمن قطر 400 متر
              if (distanceInMeters > 400.0) {
                return 'عذراً، أنت تبعد مسافة (${distanceInMeters.toStringAsFixed(0)} متر) عن موقع الحضور الصباحي. الحد المسموح هو 400 متر.';
              }
            } catch (e) {
              if (morningCoordinates != currentCoordinates) {
                return 'عذراً، يجب تسجيل الانصراف من نفس موقع العمل الذي سجلت فيه حضورك صباحاً.';
              }
            }
          }
        }

        await _db.collection('attendance').doc(doc.id).update({
          'checkoutTime': now.toIso8601String(),
        });
        foundRecord = true;
        break;
      }
    }

    if (!foundRecord) {
      return 'لم يتم العثور على تسجيل دخول لهذا العامل اليوم.';
    }
    return null;
  }

  static recordOvertime(String workerId) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final querySnapshot = await _db
        .collection('attendance')
        .where('workerId', isEqualTo: workerId)
        .get();

    bool foundRecord = false;
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final dateTimeStr = data['dateTime'] ?? '';

      if (dateTimeStr.startsWith(todayStr)) {
        if (data['checkoutTime'] == null) {
          return 'يجب تسجيل الانصراف الرسمي أولاً عند الساعة 5:00 قبل بدء/إنهاء العمل الإضافي.';
        }

        final checkoutTime = DateTime.parse(data['checkoutTime']);

        int overtimeMins = now.difference(checkoutTime).inMinutes;
        if (overtimeMins < 0) overtimeMins = 0;

        await _db.collection('attendance').doc(doc.id).update({
          'overtimeStartTime':
              data['overtimeStartTime'] ?? checkoutTime.toIso8601String(),
          'overtimeEndTime': now.toIso8601String(),
          'overtimeMinutes': overtimeMins,
        });
        foundRecord = true;
        break;
      }
    }

    if (!foundRecord) {
      return 'لم يتم العثور على سجل حضور لهذا اليوم.';
    }
    return null;
  }

  static submitWorkReport({
    required String workerId,
    required String imagePath,
    required String notes,
  }) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final querySnapshot = await _db
        .collection('attendance')
        .where('workerId', isEqualTo: workerId)
        .get();

    bool foundRecord = false;
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final dateTimeStr = data['dateTime'] ?? '';

      if (dateTimeStr.startsWith(todayStr)) {
        await _db.collection('attendance').doc(doc.id).update({
          'workDoneImage': imagePath,
          'workNotes': notes,
        });
        foundRecord = true;
        break;
      }
    }
    return foundRecord;
  }

  static Stream<List<AttendanceRecord>> getAttendanceStream() {
    return _db
        .collection('attendance')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AttendanceRecord.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}
