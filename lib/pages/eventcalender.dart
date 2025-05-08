import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class EventCalendarPage extends StatefulWidget {
  final Map<DateTime, List<Map<String, String>>>? externalEvents;

  const EventCalendarPage({super.key, this.externalEvents});

  @override
  State<EventCalendarPage> createState() => _EventCalendarPageState();
}

class _EventCalendarPageState extends State<EventCalendarPage> {
  late Map<DateTime, List<Map<String, String>>> _events;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _events = {};
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _initNotifications();
      await _loadUserEvents();
      if (widget.externalEvents != null) {
        _mergeExternalEvents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing calendar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _scheduleNotification(String title, DateTime date) async {
    try {
      final scheduledDate = date.subtract(const Duration(days: 1));
      const androidDetails = AndroidNotificationDetails(
        'event_channel',
        'Event Reminders',
        channelDescription: 'Notifications for upcoming events',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        date.hashCode,
        'Upcoming Event Reminder',
        '$title is happening tomorrow!',
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling notification: $e')),
        );
      }
    }
  }

  Future<void> _loadUserEvents() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendar_events')
          .get();

      setState(() {
        _events.clear();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final eventDate = (data['date'] as Timestamp).toDate();
          final eventDateKey =
              DateTime(eventDate.year, eventDate.month, eventDate.day);
          final event = {
            'title': data['title'] as String,
            'location': data['location'] as String,
          };
          _events[eventDateKey] = [
            ...(_events[eventDateKey] ?? []),
            event,
          ];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }
  }

  void _mergeExternalEvents() {
    for (var entry in widget.externalEvents!.entries) {
      setState(() {
        _events[entry.key] = [...(_events[entry.key] ?? []), ...entry.value];
      });
    }
  }

  Future<void> _addEventToCalendar(
      String title, String location, DateTime date) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add events')),
      );
      return;
    }

    try {
      final eventDate = DateTime(date.year, date.month, date.day);
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendar_events')
          .add({
        'title': title,
        'location': location,
        'date': eventDate,
      });

      setState(() {
        final event = {'title': title, 'location': location};
        _events[eventDate] = [...(_events[eventDate] ?? []), event];
      });

      await _scheduleNotification(title, eventDate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title added to your calendar!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding event: $e')),
        );
      }
    }
  }

  Future<void> _removeEventFromCalendar(String title, DateTime date) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to remove events')),
      );
      return;
    }

    try {
      final eventDate = DateTime(date.year, date.month, date.day);
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendar_events')
          .where('title', isEqualTo: title)
          .where('date', isEqualTo: eventDate)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _events[eventDate]?.removeWhere((event) => event['title'] == title);
        if (_events[eventDate]?.isEmpty ?? true) {
          _events.remove(eventDate);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title removed from your calendar!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing event: $e')),
        );
      }
    }
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Calendar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime(2023, 1, 1),
                  lastDay: DateTime(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: _getEventsForDay,
                  calendarStyle: const CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _selectedDay == null
                      ? const Center(child: Text('Select a date to see events'))
                      : ListView.builder(
                          itemCount: _getEventsForDay(_selectedDay!).length,
                          itemBuilder: (context, index) {
                            final event = _getEventsForDay(_selectedDay!)[index];
                            return ListTile(
                              leading: const Icon(Icons.event, color: Colors.blue),
                              title: Text(event['title'] ?? 'No Title'),
                              subtitle: Text(event['location'] ?? 'No Location'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeEventFromCalendar(
                                  event['title'] ?? '',
                                  _selectedDay!,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddEventDialog() async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Event'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Event Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setDialogState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Text(
                      selectedDate == null
                          ? 'Pick Date'
                          : 'Date: ${selectedDate!.toIso8601String().split('T')[0]}',
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty &&
                    locationController.text.isNotEmpty &&
                    selectedDate != null) {
                  _addEventToCalendar(
                    titleController.text,
                    locationController.text,
                    selectedDate!,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all fields and select a date')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}