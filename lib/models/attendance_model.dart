class WorkerModel {
  String id;
  String name;
  String siteName;
  double dailyRate;
  double advancePayment;
  bool isApproved; // الحقل الجديد للتحكم بالقبول والصلاحيات

  WorkerModel({
    required this.id,
    required this.name,
    required this.siteName,
    required this.dailyRate,
    required this.advancePayment,
    this.isApproved = false, // القيمة الافتراضية معلقة بانتظار المقاول
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'siteName': siteName,
      'dailyRate': dailyRate,
      'advancePayment': advancePayment,
      'isApproved': isApproved,
    };
  }

  factory WorkerModel.fromMap(Map<String, dynamic> data, String documentId) {
    return WorkerModel(
      id: data['id'] ?? documentId,
      name: data['name'] ?? data['Name'] ?? '',
      siteName:
          data['siteName'] ?? data['site_name'] ?? data['SiteName'] ?? 'عام',
      dailyRate:
          (data['dailyRate'] as num?)?.toDouble() ??
          (data['daily_rate'] as num?)?.toDouble() ??
          0.0,
      advancePayment:
          (data['advancePayment'] as num?)?.toDouble() ??
          (data['advance_payment'] as num?)?.toDouble() ??
          0.0,
      isApproved: data['isApproved'] ?? data['is_approved'] ?? false,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String workerId;
  final String workerName;
  final String siteName;
  final DateTime dateTime; // وقت تسجيل الدخول
  DateTime? checkoutTime; // وقت تسجيل
  DateTime? overtimeStartTime;
  int overtimeMinutes = 0;
  final String locationCoordinates;
  final String selfieImagePath;
  final double dailyRate;

  // الحقول الجديدة لتقرير الإنجاز
  String? workDoneImage;
  String? workNotes;

  AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.siteName,
    required this.dateTime,
    this.checkoutTime,
    required this.locationCoordinates,
    required this.selfieImagePath,
    required this.dailyRate,
    this.workDoneImage,
    this.workNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'siteName': siteName,
      'dateTime': dateTime.toIso8601String(),
      'checkoutTime': checkoutTime?.toIso8601String(),
      'locationCoordinates': locationCoordinates,
      'selfieImagePath': selfieImagePath,
      'dailyRate': dailyRate,
      'workDoneImage': workDoneImage,
      'workNotes': workNotes,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, String docId) {
    return AttendanceRecord(
      id: map['id'] ?? docId,
      workerId: map['workerId'] ?? '',
      workerName: map['workerName'] ?? '',
      siteName: map['siteName'] ?? '',
      dateTime: map['dateTime'] != null
          ? DateTime.parse(map['dateTime'])
          : DateTime.now(),
      checkoutTime: map['checkoutTime'] != null
          ? DateTime.parse(map['checkoutTime'])
          : null,
      locationCoordinates: map['locationCoordinates'] ?? '',
      selfieImagePath: map['selfieImagePath'] ?? '',
      dailyRate: (map['dailyRate'] as num?)?.toDouble() ?? 0.0,
      workDoneImage: map['workDoneImage'],
      workNotes: map['workNotes'],
    );
  }
}
