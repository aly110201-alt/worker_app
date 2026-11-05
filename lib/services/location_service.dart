import 'package:geolocator/geolocator.dart';

class LocationService {
  // التحقق من صلاحيات الموقع وجلبه
  static Future<String> getCurrentLocationCoordinates() async {
    bool serviceEnabled;
    LocationPermission permission;

    // التحقق هل خدمة الموقع مفعلة في الهاتف
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'خدمة الموقع الجغرافي (GPS) غير مفعلة. يرجى تفعيلها.';
    }

    // التحقق من الصلاحيات
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'تم رفض صلاحية الوصول إلى الموقع الجغرافي.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'صلاحيات الموقع مرفوضة بشكل دائم، يرجى تفعيلها من إعدادات التطبيق.';
    }

    // جلب الإحداثيات الحالية بدقة
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
  }
}
