import 'field_task.dart';

/// One action a worker can take on a task, as the server names it in
/// `allowed_actions`, and how the app asks for it.
class TaskAction {
  const TaskAction({
    required this.key,
    required this.label,
    required this.path,
    this.inputField,
    this.inputLabel,
    this.isCompletion = false,
  });

  /// The name in `allowed_actions`.
  final String key;
  final String label;

  /// The path segment after `/{id}/` on the domain's endpoint.
  final String path;

  /// The body field this action needs typed in, if any.
  final String? inputField;
  final String? inputLabel;

  /// Reporting the work done. It is a report, not a closure: the order still
  /// has to be verified and accepted on the server's side.
  final bool isCompletion;

  bool get needsInput => inputField != null;

  /// The actions each domain's API takes. A key the server sends that is not
  /// listed here is not shown - the app never invents a request.
  static const Map<TaskDomain, List<TaskAction>> byDomain = {
    TaskDomain.gams: [
      TaskAction(key: 'accept', label: 'Terima Tugas', path: 'accept'),
      TaskAction(key: 'start', label: 'Mulai Pekerjaan', path: 'start'),
      TaskAction(
        key: 'hold',
        label: 'Tunda',
        path: 'hold',
        inputField: 'reason',
        inputLabel: 'Alasan penundaan',
      ),
      TaskAction(key: 'resume', label: 'Lanjutkan', path: 'resume'),
      TaskAction(
        key: 'complete',
        label: 'Laporkan Selesai',
        path: 'complete',
        inputField: 'completion_notes',
        inputLabel: 'Laporan pekerjaan',
        isCompletion: true,
      ),
    ],
    TaskDomain.itms: [
      TaskAction(key: 'start', label: 'Mulai Pekerjaan', path: 'start'),
      TaskAction(
        key: 'progress',
        label: 'Catat Progres',
        path: 'progress',
        inputField: 'note',
        inputLabel: 'Catatan progres pekerjaan',
      ),
      TaskAction(
        key: 'wait',
        label: 'Tunggu',
        path: 'wait',
        inputField: 'reason',
        inputLabel: 'Yang sedang ditunggu (suku cadang, vendor, pengguna)',
      ),
      TaskAction(key: 'resume', label: 'Lanjutkan', path: 'resume'),
      TaskAction(
        key: 'resolve',
        label: 'Laporkan Selesai',
        path: 'resolve',
        inputField: 'resolution_notes',
        inputLabel: 'Laporan penyelesaian',
        isCompletion: true,
      ),
    ],
    TaskDomain.mtms: [
      TaskAction(key: 'start', label: 'Mulai Pekerjaan', path: 'start'),
      TaskAction(key: 'resume', label: 'Lanjutkan', path: 'start'),
      TaskAction(
        key: 'start_labor',
        label: 'Mulai Catat Jam Kerja',
        path: 'labor/start',
      ),
      TaskAction(
        key: 'stop_labor',
        label: 'Selesai Catat Jam Kerja',
        path: 'labor/stop',
      ),
      TaskAction(
        key: 'hold',
        label: 'Tahan',
        path: 'hold',
        inputField: 'reason',
        inputLabel: 'Alasan ditahan',
      ),
      TaskAction(
        key: 'complete',
        label: 'Laporkan Selesai Teknis',
        path: 'complete',
        inputField: 'notes',
        inputLabel: 'Laporan teknis',
        isCompletion: true,
      ),
    ],
  };

  /// The buttons for a task: the server's allowed actions, in the server's
  /// order, that this app knows how to send. `complete_task` is offered per
  /// step instead of as a button.
  static List<TaskAction> forTask(FieldTask task) {
    final known = byDomain[task.domain] ?? const [];

    return task.allowedActions
        .map((key) => known.where((a) => a.key == key).firstOrNull)
        .whereType<TaskAction>()
        .toList();
  }
}
