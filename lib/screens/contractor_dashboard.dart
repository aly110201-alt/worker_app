import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attendance_model.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import 'login_screen.dart';

class ContractorDashboard extends StatefulWidget {
  const ContractorDashboard({super.key});

  @override
  State<ContractorDashboard> createState() => _ContractorDashboardState();
}

class _ContractorDashboardState extends State<ContractorDashboard> {
  List<WorkerModel> currentWorkers = [];
  List<AttendanceRecord> currentRecords = [];

  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _advanceController = TextEditingController();
  final TextEditingController _settlementController = TextEditingController();

  String? _selectedWorkerEmail;
  String? _selectedSiteName;

  Future<void> _openMap(String coordinates) async {
    if (coordinates == '0.0, 0.0' || coordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إحداثيات الموقع غير متوفرة لهذا السجل')),
      );
      return;
    }
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$coordinates',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر فتح خريطة الموقع')));
    }
  }

  void _showImageViewer(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صورة إنجاز العمل / الحضور'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: (imagePath == 'none' || imagePath.isEmpty)
              ? const Center(
                  child: Text(
                    'لا توجد صورة مرفقة',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : imagePath.startsWith('http')
              ? InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Text(
                              'تعذر تحميل الصورة من الرابط',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    'مسار الصورة غير صالح: $imagePath',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _addNewSiteDialog() {
    final siteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة موقع عمل جديد'),
        content: TextField(
          controller: siteController,
          decoration: const InputDecoration(
            labelText: 'اسم الموقع',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            onPressed: () async {
              if (siteController.text.trim().isNotEmpty) {
                await DatabaseService.addSite(siteController.text.trim());
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت إضافة الموقع بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _assignTask() async {
    if (_selectedWorkerEmail == null ||
        _selectedSiteName == null ||
        _taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار العامل والموقع وكتابة تفاصيل المهمة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final taskText = _taskController.text.trim();
    final workerEmail = _selectedWorkerEmail!;
    final siteName = _selectedSiteName!;

    final task = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workerEmail: workerEmail,
      siteName: siteName,
      taskDescription: taskText,
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );

    _taskController.clear();
    await DatabaseService.assignTask(task);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إسناد المهمة للعامل بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _editTaskDialog(TaskModel task) {
    final taskDescController = TextEditingController(
      text: task.taskDescription,
    );
    final siteController = TextEditingController(text: task.siteName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل المهمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: siteController,
              decoration: const InputDecoration(
                labelText: 'اسم الموقع',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: taskDescController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل المهمة',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            onPressed: () async {
              final updatedTask = TaskModel(
                id: task.id,
                workerEmail: task.workerEmail,
                siteName: siteController.text.trim(),
                taskDescription: taskDescController.text.trim(),
                date: task.date,
                isCompleted: task.isCompleted,
              );

              await DatabaseService.assignTask(updatedTask);
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تعديل المهمة بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'حفظ التعديلات',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(String taskId) async {
    await DatabaseService.deleteTask(taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المهمة بنجاح'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addAdvanceForWorker() async {
    final amount = double.tryParse(_advanceController.text.trim());
    if (_selectedWorkerEmail == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار العامل وإدخال مبلغ سلفة صحيح'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final advance = AdvanceModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workerEmail: _selectedWorkerEmail!,
      amount: amount,
      dateTime: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );

    await DatabaseService.addAdvance(advance);
    _advanceController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة السلفة الجديدة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _settleWorkerAccount() async {
    final finalAmount = double.tryParse(_settlementController.text.trim());
    if (_selectedWorkerEmail == null || finalAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى اختيار العامل وإدخال المبلغ النهائي لتسكير الحساب',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await DatabaseService.settleAccount(_selectedWorkerEmail!, finalAmount);
    _settlementController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسكير الحساب وتصفير الرصيد بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _addNewWorker() {
    final dialogNameController = TextEditingController();
    final dialogSiteController = TextEditingController();
    final dialogRateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عامل جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dialogNameController,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني للعامل (مثلاً worker11@...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dialogSiteController,
              decoration: const InputDecoration(
                labelText: 'اسم الموقع',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dialogRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قيمة اليومية',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            onPressed: () async {
              try {
                if (dialogNameController.text.trim().isNotEmpty &&
                    dialogRateController.text.trim().isNotEmpty) {
                  final newWorker = WorkerModel(
                    id: dialogNameController.text.trim().toLowerCase(),
                    name: dialogNameController.text.trim(),
                    siteName: dialogSiteController.text.trim().isEmpty
                        ? 'عام'
                        : dialogSiteController.text.trim(),
                    dailyRate:
                        double.tryParse(dialogRateController.text.trim()) ??
                        0.0,
                    advancePayment: 0.0,
                  );

                  await DatabaseService.addWorker(newWorker);
                  await DatabaseService.approveWorker(newWorker.id, true);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ وتفعيل العامل بنجاح'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
                  );
                }
              }
            },
            child: const Text(
              'حفظ العامل',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _editWorkerDialog(WorkerModel worker) {
    final nameController = TextEditingController(text: worker.name);
    final siteController = TextEditingController(text: worker.siteName);
    final rateController = TextEditingController(
      text: worker.dailyRate.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل بيانات: ${worker.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العامل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: siteController,
                decoration: const InputDecoration(
                  labelText: 'اسم الموقع',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'قيمة اليومية',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            onPressed: () async {
              worker.name = nameController.text.trim();
              worker.siteName = siteController.text.trim();
              worker.dailyRate =
                  double.tryParse(rateController.text) ?? worker.dailyRate;

              await DatabaseService.updateWorker(worker);
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'حفظ التعديلات',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم المقاول السحابية',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'تصدير الجرد الشهري إكسل',
            onPressed: () => ExcelService.exportMonthlyReport(
              currentRecords,
              currentWorkers,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'إدارة المواقع وإسناد المهام والسلاف',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                          onPressed: _addNewSiteDialog,
                          icon: const Icon(
                            Icons.add_location,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'إضافة موقع',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    StreamBuilder<List<String>>(
                      stream: DatabaseService.getSitesStream(),
                      builder: (context, snapshot) {
                        final sites = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: _selectedSiteName,
                          hint: const Text('اختر موقع العمل'),
                          items: sites
                              .map(
                                (site) => DropdownMenuItem(
                                  value: site,
                                  child: Text(site),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedSiteName = val),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<WorkerModel>>(
                      stream: DatabaseService.getWorkersStream(),
                      builder: (context, snapshot) {
                        currentWorkers = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: _selectedWorkerEmail,
                          hint: const Text('اختر العامل'),
                          items: currentWorkers
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text('${w.name} (${w.siteName})'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedWorkerEmail = val),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _taskController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'تفاصيل العمل المطلوب إنجازه للعامل...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      onPressed: _assignTask,
                      icon: const Icon(
                        Icons.assignment_turned_in,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'إسناد المهمة للعامل',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _advanceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مبلغ السلفة الجديدة',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                          ),
                          onPressed: _addAdvanceForWorker,
                          child: const Text(
                            'إضافة سلفة',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _settlementController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المبلغ النهائي لتسكير الحساب',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                          ),
                          onPressed: _settleWorkerAccount,
                          child: const Text(
                            'تسكير الحساب (0)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'قائمة العمال والتحكم بالصلاحيات والقبول',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // قائمة العمال والتحكم
            StreamBuilder<List<WorkerModel>>(
              stream: DatabaseService.getWorkersStream(),
              builder: (context, snapshot) {
                currentWorkers = snapshot.data ?? [];
                if (currentWorkers.isEmpty) {
                  return const Center(child: Text('لا يوجد عمال مسجلين.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = currentWorkers[index];
                    bool isApproved = worker.isApproved;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isApproved
                              ? Colors.green[100]
                              : Colors.orange[100],
                          child: Icon(
                            Icons.person,
                            color: isApproved
                                ? Colors.green[800]
                                : Colors.orange[800],
                          ),
                        ),
                        title: Text(
                          worker.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'الموقع: ${worker.siteName} | اليومية: ${worker.dailyRate}\nالحالة: ${isApproved ? "مفعل ومصرح له بالدخول" : "بانتظار الموافقة (معلق)"}',
                          style: TextStyle(
                            color: isApproved
                                ? Colors.black87
                                : Colors.red[700],
                            fontWeight: isApproved
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isApproved,
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              inactiveTrackColor: Colors.red[100],
                              onChanged: (val) async {
                                await DatabaseService.approveWorker(
                                  worker.id,
                                  val,
                                );
                                setState(() {});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        val
                                            ? 'تمت الموافقة وتفعيل حساب العامل بنجاح'
                                            : 'تم إلغاء تفعيل الحساب وسحب الصلاحية',
                                      ),
                                      backgroundColor: val
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Color(0xFF1E3A8A),
                              ),
                              onPressed: () => _editWorkerDialog(worker),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await DatabaseService.deleteWorker(worker.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم حذف العامل بنجاح'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 32, thickness: 2),
            const Text(
              'سجلات حضور وانصراف العمال',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<AttendanceRecord>>(
              stream: DatabaseService.getAttendanceStream(),
              builder: (context, snapshot) {
                currentRecords = snapshot.data ?? [];
                if (currentRecords.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('لا توجد سجلات حضور بعد.'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentRecords.length,
                  itemBuilder: (context, index) {
                    final record = currentRecords[index];
                    final checkInStr = DateFormat('yyyy-MM-dd HH:mm')
                        .format(record.dateTime);
                    final checkOutStr = record.checkoutTime != null
                        ? DateFormat('HH:mm').format(record.checkoutTime!)
                        : 'لم يسجل خروج بعد';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  record.workerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'اليومية: ${record.dailyRate}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'الموقع: ${record.siteName}\nدخول: $checkInStr | خروج: $checkOutStr\nملاحظات العمل: ${record.workNotes ?? 'لا توجد ملاحظات'}',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E3A8A),
                                  ),
                                  onPressed: () =>
                                      _openMap(record.locationCoordinates),
                                  icon: const Icon(Icons.map, size: 18),
                                  label: const Text('فتح الموقع (GPS)'),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange[800],
                                  ),
                                  onPressed: () => _showImageViewer(
                                    record.workDoneImage ??
                                        record.selfieImagePath,
                                  ),
                                  icon: const Icon(Icons.image, size: 18),
                                  label: const Text('مشاهدة الصورة'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 32, thickness: 2),

            // --- قسم قائمة المهام المسندة إلى العمال (موضوعة تحت سجلات الحضور مع أزرار التعديل والحذف) ---
            const Text(
              'قائمة المهام المسندة إلى العمال',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('لا توجد مهام مسندة حالياً.'),
                    ),
                  );
                }

                final taskDocs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: taskDocs.length,
                  itemBuilder: (context, index) {
                    final taskDoc = taskDocs[index];
                    final taskData = taskDoc.data() as Map<String, dynamic>;

                    final task = TaskModel.fromMap(taskData, taskDoc.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          'العامل: ${task.workerEmail} | الموقع: ${task.siteName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'المهمة: ${task.taskDescription}\nالتاريخ: ${task.date} | الحالة: ${task.isCompleted ? "منجزة ✅" : "قيد التنفيذ ⏳"}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editTaskDialog(task),
                              tooltip: 'تعديل المهمة',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTask(task.id),
                              tooltip: 'حذف المهمة',
                            ),
                          ],
                        ),
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
