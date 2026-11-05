import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/attendance_model.dart';

class ExcelService {
  static Future<void> exportMonthlyReport(
    List<AttendanceRecord> records,
    List<WorkerModel> workers,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['جرد الحساب الشهري'];

    excel.delete('Sheet1');

    sheetObject.appendRow([
      TextCellValue('اسم العامل'),
      TextCellValue('الموقع'),
      TextCellValue('أيام حضور'),
      TextCellValue('قيمة اليومية'),
      TextCellValue('إجمالي المستحق'),
      TextCellValue('السلف المدفوعة'),
      TextCellValue('الصافي النهائي'),
    ]);

    for (var worker in workers) {
      int workerDays = records.where((r) => r.workerId == worker.id).length;
      double totalEarned = workerDays * worker.dailyRate;
      double netPayable = totalEarned - worker.advancePayment;

      sheetObject.appendRow([
        TextCellValue(worker.name),
        TextCellValue(worker.siteName),
        IntCellValue(workerDays),
        DoubleCellValue(worker.dailyRate),
        DoubleCellValue(totalEarned),
        DoubleCellValue(worker.advancePayment),
        DoubleCellValue(netPayable),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/Monthly_Attendance_Report.xlsx';
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'تقرير جرد حضور ورواتب العمال الشهري');
    }
  }
}
