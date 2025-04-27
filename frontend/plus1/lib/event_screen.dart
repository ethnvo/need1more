import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  _EventScreenState createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _eventController = TextEditingController();
  final _peopleController = TextEditingController();
  final _database = FirebaseDatabase.instance.ref();

  final List<Map<String, dynamic>> _events = [];
  final Map<String, Timer> _eventTimers = {}; // 🔥 Timers for auto-delete
  Timer? _countdownTimer; // 🔥 Timer for refreshing countdowns
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();

    _database.child('events').onChildAdded.listen((DatabaseEvent event) {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (eventData != null) {
        final newEvent = Map<String, dynamic>.from(eventData);
        newEvent['key'] = event.snapshot.key;

        final now = DateTime.now().millisecondsSinceEpoch;
        final eventTimeRaw = newEvent['eventTime'];
        final eventTime = eventTimeRaw is int
            ? eventTimeRaw
            : int.tryParse(eventTimeRaw.toString()) ?? 0;

        if (eventTime > now) {
          setState(() {
            _events.add(newEvent);
            _events.sort((a, b) {
              final at = (a['eventTime'] is int)
                  ? a['eventTime']
                  : int.tryParse(a['eventTime'].toString()) ?? 0;
              final bt = (b['eventTime'] is int)
                  ? b['eventTime']
                  : int.tryParse(b['eventTime'].toString()) ?? 0;
              return at.compareTo(bt);
            });
          });

          // 🔥 Schedule auto-delete exactly when event expires
          final durationUntilDelete = Duration(milliseconds: eventTime - now);
          final timer = Timer(durationUntilDelete, () {
            final eventKey = event.snapshot.key;
            if (eventKey != null) {
              _database.child('events').child(eventKey).remove();
              print('Auto-deleted expired event: ${newEvent['eventName']}');
            }
          });

          if (event.snapshot.key != null) {
            _eventTimers[event.snapshot.key!] = timer;
          }
        } else {
          // Expired event — delete immediately
          final eventKey = event.snapshot.key;
          if (eventKey != null) {
            _database.child('events').child(eventKey).remove().then((_) {
              print('Deleted already expired event: ${newEvent['eventName']}');
            }).catchError((error) {
              print('Failed to delete expired event: $error');
            });
          }
        }
      }
    });

    _database.child('events').onChildChanged.listen((DatabaseEvent event) {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (eventData != null) {
        final updatedEvent = Map<String, dynamic>.from(eventData);
        updatedEvent['key'] = event.snapshot.key;

        final now = DateTime.now().millisecondsSinceEpoch;
        final eventTimeRaw = updatedEvent['eventTime'];
        final eventTime = eventTimeRaw is int
            ? eventTimeRaw
            : int.tryParse(eventTimeRaw.toString()) ?? 0;

        if (eventTime > now) {
          final index = _events.indexWhere((e) => e['key'] == updatedEvent['key']);
          if (index != -1) {
            setState(() {
              _events[index] = updatedEvent;
              _events.sort((a, b) {
                final at = (a['eventTime'] is int)
                    ? a['eventTime']
                    : int.tryParse(a['eventTime'].toString()) ?? 0;
                final bt = (b['eventTime'] is int)
                    ? b['eventTime']
                    : int.tryParse(b['eventTime'].toString()) ?? 0;
                return at.compareTo(bt);
              });
            });
          }
        } else {
          // Expired event after update — remove locally
          setState(() {
            _events.removeWhere((e) => e['key'] == updatedEvent['key']);
          });
          final eventKey = event.snapshot.key;
          if (eventKey != null) {
            _database.child('events').child(eventKey).remove();
          }
        }
      }
    });

    _database.child('events').onChildRemoved.listen((DatabaseEvent event) {
      final eventKey = event.snapshot.key;
      if (eventKey != null) {
        _eventTimers[eventKey]?.cancel();
        _eventTimers.remove(eventKey);

        setState(() {
          _events.removeWhere((e) => e['key'] == eventKey);
        });
      }
    });

    // 🔥 Start global countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {}); // Refresh UI every second for countdowns
    });
  }

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _addEvent() {
    final eventName = _eventController.text.trim();
    final peopleCount = int.tryParse(_peopleController.text.trim()) ?? 0;

    if (eventName.isNotEmpty && peopleCount > 0 && _selectedDateTime != null) {
      final eventData = {
        'eventName': eventName,
        'peopleCount': peopleCount,
        'eventTime': _selectedDateTime!.millisecondsSinceEpoch,
        'id': DateTime.now().toIso8601String(),
      };
      _database.child('events').push().set(eventData);

      _eventController.clear();
      _peopleController.clear();
      _selectedDateTime = null;
    }
  }

  void _deleteEvent(String eventKey) {
    _database.child('events').child(eventKey).remove().then((_) {
      print('Event deleted successfully');
    }).catchError((error) {
      print('Failed to delete event: $error');
    });
  }

  String _buildCountdownText(int eventTime) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = eventTime - now;

    if (diffMs <= 0) {
      return "Starting Now!";
    } else {
      final minutes = (diffMs ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((diffMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      return "Starting Soon: $minutes:$seconds";
    }
  }

  @override
  void dispose() {
    for (var timer in _eventTimers.values) {
      timer.cancel();
    }
    _eventTimers.clear();
    _countdownTimer?.cancel();
    _eventController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Bulletin Board'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _eventController,
              decoration: const InputDecoration(labelText: 'Event Name'),
            ),
            TextField(
              controller: _peopleController,
              decoration: const InputDecoration(labelText: 'People Needed'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickDateTime,
              child: Text(
                _selectedDateTime == null
                    ? 'Pick Event Time'
                    : 'Event Time: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime!.toLocal())}',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addEvent,
              child: const Text('Add Event'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _events.isEmpty
                  ? const Center(child: Text('No events found'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final eventTime = event['eventTime'] is int
                            ? event['eventTime']
                            : int.tryParse(event['eventTime'].toString()) ?? 0;
                        final formattedTime = DateFormat('yyyy-MM-dd HH:mm')
                            .format(DateTime.fromMillisecondsSinceEpoch(eventTime));
                        final isStartingSoon = eventTime - DateTime.now().millisecondsSinceEpoch <= 10 * 60 * 1000;

                        return ListTile(
                          title: Text(event['eventName']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${event['peopleCount']} people needed'),
                              Text('At: $formattedTime'),
                              if (isStartingSoon)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    _buildCountdownText(eventTime),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteEvent(event['key']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
