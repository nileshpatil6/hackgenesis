import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../models/calendar.dart';
import '../../services/database_service.dart';
import '../../providers/subject_provider.dart';

class AddEventScreen extends StatefulWidget {
  final DateTime selectedDate;
  final CalendarEvent? event; // For editing existing event

  const AddEventScreen({
    super.key,
    required this.selectedDate,
    this.event,
  });

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _eventType = EventType.study;
  String? _selectedSubjectId;
  int _priority = 2;
  bool _hasReminder = false;
  List<int> _reminderMinutes = [15];
  bool _isAllDay = true;

  @override
  void initState() {
    super.initState();

    if (widget.event != null) {
      // Editing existing event
      final event = widget.event!;
      _titleController = TextEditingController(text: event.title);
      _descriptionController =
          TextEditingController(text: event.description ?? '');
      _locationController = TextEditingController(text: event.location ?? '');
      _notesController = TextEditingController(text: event.notes ?? '');
      _selectedDate = event.date;
      _eventType = event.eventType;
      _selectedSubjectId = event.subjectId;
      _priority = event.priority;
      _hasReminder = event.hasReminder;
      _reminderMinutes = event.reminderMinutesBefore ?? [15];

      if (event.startTime != null) {
        _isAllDay = false;
        _startTime = TimeOfDay.fromDateTime(event.startTime!);
        if (event.endTime != null) {
          _endTime = TimeOfDay.fromDateTime(event.endTime!);
        }
      }
    } else {
      // Creating new event
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      _notesController = TextEditingController();
      _selectedDate = widget.selectedDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime? startDateTime;
    DateTime? endDateTime;

    if (!_isAllDay && _startTime != null) {
      startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      if (_endTime != null) {
        endDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }
    }

    final event = CalendarEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: _titleController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      date: _selectedDate,
      startTime: startDateTime,
      endTime: endDateTime,
      eventType: _eventType,
      subjectId: _selectedSubjectId,
      priority: _priority,
      hasReminder: _hasReminder,
      reminderMinutesBefore: _hasReminder ? _reminderMinutes : null,
      location:
          _locationController.text.isEmpty ? null : _locationController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: widget.event?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.event != null) {
      await _dbService.updateCalendarEvent(event);
    } else {
      await _dbService.saveCalendarEvent(event);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.event != null) {
      await _dbService.deleteCalendarEvent(widget.event!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? 'Edit Event' : 'Add Event'),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteEvent,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title *',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Event Type
            DropdownButtonFormField<String>(
              initialValue: _eventType,
              decoration: const InputDecoration(
                labelText: 'Event Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: EventType.all.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Text(EventType.getEmoji(type)),
                      const SizedBox(width: 8),
                      Text(EventType.getDisplayName(type)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _eventType = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Link to Subject
            Consumer<SubjectProvider>(
              builder: (context, subjectProvider, child) {
                final subjects = subjectProvider.subjects;

                return DropdownButtonFormField<String?>(
                  initialValue: _selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Link to Subject (Optional)',
                    prefixIcon: Icon(Icons.book),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No subject'),
                    ),
                    ...subjects.map((subject) {
                      return DropdownMenuItem(
                        value: subject.id,
                        child: Text(subject.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSubjectId = value;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(_formatDate(_selectedDate)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
            ),

            const SizedBox(height: 8),

            // All Day Toggle
            SwitchListTile(
              title: const Text('All Day Event'),
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value;
                  if (value) {
                    _startTime = null;
                    _endTime = null;
                  }
                });
              },
            ),

            if (!_isAllDay) ...[
              const SizedBox(height: 8),

              // Start Time
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Start Time'),
                subtitle: Text(_startTime != null
                    ? _startTime!.format(context)
                    : 'Not set'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _startTime ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _startTime = time;
                    });
                  }
                },
              ),

              // End Time
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('End Time'),
                subtitle: Text(
                    _endTime != null ? _endTime!.format(context) : 'Not set'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _endTime ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _endTime = time;
                    });
                  }
                },
              ),
            ],

            const SizedBox(height: 16),

            // Priority
            const Text('Priority',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPriorityChip('Low', 1, Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriorityChip('Medium', 2, Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriorityChip('High', 3, Colors.red),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reminder
            SwitchListTile(
              title: const Text('Set Reminder'),
              value: _hasReminder,
              onChanged: (value) {
                setState(() {
                  _hasReminder = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 4,
            ),

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton.icon(
              onPressed: _saveEvent,
              icon: const Icon(Icons.save),
              label:
                  Text(widget.event != null ? 'Update Event' : 'Create Event'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, int value, Color color) {
    final isSelected = _priority == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _priority = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
