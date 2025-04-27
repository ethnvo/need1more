import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plus1/home_screen.dart';

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
  final Map<String, Timer> _eventTimers = {};
  Timer? _countdownTimer;
  late StreamSubscription<DatabaseEvent> _addedSub;
  late StreamSubscription<DatabaseEvent> _changedSub;
  late StreamSubscription<DatabaseEvent> _removedSub;
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();

    _addedSub = _database.child('events').onChildAdded.listen(_onEventAdded);
    _changedSub = _database.child('events').onChildChanged.listen(_onEventChanged);
    _removedSub = _database.child('events').onChildRemoved.listen(_onEventRemoved);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onEventAdded(DatabaseEvent event) {
    if (!mounted) return;
    final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
    if (eventData != null) {
      final newEvent = Map<String, dynamic>.from(eventData);
      newEvent['key'] = event.snapshot.key;

      final now = DateTime.now().millisecondsSinceEpoch;
      final eventTime = int.tryParse(newEvent['eventTime'].toString()) ?? 0;

      if (eventTime > now) {
        setState(() {
          _events.add(newEvent);
          _events.sort((a, b) => (a['eventTime'] as int).compareTo(b['eventTime'] as int));
        });

        final durationUntilDelete = Duration(milliseconds: eventTime - now);
        final timer = Timer(durationUntilDelete, () {
          if (mounted && event.snapshot.key != null) {
            _database.child('events').child(event.snapshot.key!).remove();
          }
        });
        if (event.snapshot.key != null) {
          _eventTimers[event.snapshot.key!] = timer;
        }
      } else {
        if (event.snapshot.key != null) {
          _database.child('events').child(event.snapshot.key!).remove();
        }
      }
    }
  }

  void _onEventChanged(DatabaseEvent event) {
    if (!mounted) return;
    final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
    if (eventData != null) {
      final updatedEvent = Map<String, dynamic>.from(eventData);
      updatedEvent['key'] = event.snapshot.key;

      final now = DateTime.now().millisecondsSinceEpoch;
      final eventTime = int.tryParse(updatedEvent['eventTime'].toString()) ?? 0;

      if (eventTime > now) {
        final index = _events.indexWhere((e) => e['key'] == updatedEvent['key']);
        if (index != -1) {
          setState(() {
            _events[index] = updatedEvent;
            _events.sort((a, b) => (a['eventTime'] as int).compareTo(b['eventTime'] as int));
          });
        }
      } else {
        setState(() {
          _events.removeWhere((e) => e['key'] == updatedEvent['key']);
        });
        if (event.snapshot.key != null) {
          _database.child('events').child(event.snapshot.key!).remove();
        }
      }
    }
  }

  void _onEventRemoved(DatabaseEvent event) {
    if (!mounted) return;
    final eventKey = event.snapshot.key;
    if (eventKey != null) {
      _eventTimers[eventKey]?.cancel();
      _eventTimers.remove(eventKey);
      setState(() {
        _events.removeWhere((e) => e['key'] == eventKey);
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final fiveMinutesLater = now.add(const Duration(minutes: 5));

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: fiveMinutesLater,
      firstDate: now,
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: fiveMinutesLater.hour,
          minute: fiveMinutesLater.minute,
        ),
      );

      if (pickedTime != null) {
        final pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (pickedDateTime.isBefore(fiveMinutesLater)) {
          showMessage('Event must start at least 5 minutes from now.');
          return;
        }

        setState(() {
          _selectedDateTime = pickedDateTime;
        });
      }
    }
  }

  void _addEvent() {
    final eventName = _eventController.text.trim();
    final peopleCount = int.tryParse(_peopleController.text.trim()) ?? 0;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (eventName.isNotEmpty && peopleCount > 0 && _selectedDateTime != null && uid != null) {
      if (_selectedDateTime!.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
        showMessage('Event time must be at least 5 minutes in the future.');
        return;
      }

      final eventData = {
        'eventName': eventName,
        'peopleCount': peopleCount,
        'eventTime': _selectedDateTime!.millisecondsSinceEpoch,
        'id': DateTime.now().toIso8601String(),
        'ownerUid': uid,
      };
      _database.child('events').push().set(eventData);

      _eventController.clear();
      _peopleController.clear();
      _selectedDateTime = null;
    } else {
      showMessage('Please complete all fields correctly.');
    }
  }

  Future<void> _joinEvent(Map<String, dynamic> event) async {
    final eventKey = event['key'];
    final eventRef = _database.child('events/$eventKey');
    final snapshot = await eventRef.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final currentPeople = data['peopleCount'] ?? 0;

    if (currentPeople > 1) {
      await eventRef.update({'peopleCount': currentPeople - 1});
    } else {
      final ownerUid = data['ownerUid'];
      if (ownerUid != null) {
        final userSnapshot = await _database.child('users/$ownerUid').get();
        final phone = userSnapshot.child('phone').value;
        if (phone != null) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Event Full!'),
                content: Text('Contact: $phone'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
      await eventRef.remove();
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (var timer in _eventTimers.values) {
      timer.cancel();
    }
    _eventTimers.clear();
    _countdownTimer?.cancel();
    _addedSub.cancel();
    _changedSub.cancel();
    _removedSub.cancel();
    _eventController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Bulletin Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
        ],
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
                        final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
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
                          trailing: ElevatedButton(
                            onPressed: () => _joinEvent(event),
                            child: const Text('Join'),
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
}
