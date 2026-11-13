import 'package:esas/features/tasks/data/models/field_task.dart';
import 'package:esas/features/tasks/data/models/task_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a GAMS list item reads its first-release keys subject and facility_name',
    () {
      final task = FieldTask.fromJson(TaskDomain.gams, {
        'id': 7,
        'number': 'WO-00000007',
        'subject': 'Bersihkan pantry',
        'facility_name': 'Gedung A',
        'priority': 'normal',
        'status': 'issued',
        'status_label': 'Issued',
        'lock_version': 2,
        'allowed_actions': ['accept'],
      });

      expect(task.title, 'Bersihkan pantry');
      expect(task.location, 'Gedung A');
      expect(task.lockVersion, 2);
      expect(task.needsAction, isTrue);
    },
  );

  test('an MTMS detail carries its tasks, labor and history', () {
    final detail = FieldTaskDetail.fromJson(TaskDomain.mtms, {
      'id': 3,
      'number': 'WO-MT-3',
      'title': 'Corrective — Pompa',
      'location': 'Plant 1',
      'status': 'in_progress',
      'status_label': 'Dikerjakan',
      'technical_completion_notes': null,
      'tasks': [
        {
          'id': 11,
          'description': 'Ganti seal',
          'is_mandatory': true,
          'is_done': false,
        },
      ],
      'labor': [
        {'id': 5, 'started_at': '2026-11-12T08:00:00+07:00', 'ended_at': null},
      ],
      'history': [
        {
          'to': 'in_progress',
          'to_label': 'Dikerjakan',
          'at': '2026-11-12T08:00:00+07:00',
        },
      ],
      'allowed_actions': ['hold', 'complete_task', 'stop_labor', 'complete'],
    });

    expect(detail.steps.single.isMandatory, isTrue);
    expect(detail.steps.single.isDone, isFalse);
    expect(detail.labor.single.isOpen, isTrue);
    expect(detail.history.single.label, 'Dikerjakan');
  });

  test(
    'the buttons are the server\'s allowed actions this app knows, in order',
    () {
      final task = FieldTask.fromJson(TaskDomain.mtms, {
        'id': 1,
        'status': 'in_progress',
        'allowed_actions': [
          'hold',
          'complete_task',
          'stop_labor',
          'unknown_thing',
          'complete',
        ],
      });

      final actions = TaskAction.forTask(task);

      // `complete_task` is offered per step, and an unknown key is never sent.
      expect(actions.map((a) => a.key), ['hold', 'stop_labor', 'complete']);
      expect(actions.last.isCompletion, isTrue);
      expect(actions.last.inputField, 'notes');
    },
  );

  test('a task with no allowed actions shows no buttons', () {
    final task = FieldTask.fromJson(TaskDomain.itms, {
      'id': 1,
      'status': 'resolved',
    });

    expect(TaskAction.forTask(task), isEmpty);
    expect(task.needsAction, isFalse);
  });
}
