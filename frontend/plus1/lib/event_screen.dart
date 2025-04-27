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
  final Set<String> _expandedEvents = {};
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
      if (mounted) setState(() {});
    });
  }

  void _onEventAdded(DatabaseEvent event) {
    if (!mounted) return;
    final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
    if (eventData != null) {
      final newEvent = Map<String, dynamic>.from(eventData)..['key'] = event.snapshot.key;
      final now = DateTime.now().millisecondsSinceEpoch;
      final eventTime = int.tryParse(newEvent['eventTime'].toString()) ?? 0;

      if (eventTime > now) {
        setState(() {
          _events.add(newEvent);
          _events.sort((a, b) => (a['eventTime'] as int).compareTo(b['eventTime'] as int));
        });

        final timer = Timer(Duration(milliseconds: eventTime - now), () {
          if (mounted && event.snapshot.key != null) {
            _database.child('events').child(event.snapshot.key!).remove();
          }
        });
        _eventTimers[event.snapshot.key!] = timer;
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
      final updatedEvent = Map<String, dynamic>.from(eventData)..['key'] = event.snapshot.key;
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

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: fiveMinutesLater,
      firstDate: now,
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: fiveMinutesLater.hour, minute: fiveMinutesLater.minute),
      );

      if (pickedTime != null) {
        var pickedDateTime = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute,
        );

        if (pickedDateTime.isBefore(fiveMinutesLater)) {
          pickedDateTime = fiveMinutesLater;
        }

        setState(() => _selectedDateTime = pickedDateTime);
      }
    }
  }

  void _addEvent() {
    final eventName = _eventController.text.trim();
    final peopleCount = int.tryParse(_peopleController.text.trim()) ?? 0;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (eventName.isNotEmpty && peopleCount > 0 && _selectedDateTime != null && uid != null) {
      final eventData = {
        'eventName': eventName,
        'peopleCount': peopleCount,
        'eventTime': _selectedDateTime!.millisecondsSinceEpoch,
        'id': DateTime.now().toIso8601String(),
        'ownerUid': uid,
        'signups': [],
      };
      _database.child('events').push().set(eventData);

      _eventController.clear();
      _peopleController.clear();
      _selectedDateTime = null;
    } else {
      _showMessage('Please complete all fields correctly.');
    }
  }

  Future<void> _joinEvent(Map<String, dynamic> event) async {
    final eventKey = event['key'];
    final eventRef = _database.child('events/$eventKey');
    final snapshot = await eventRef.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final currentUser = FirebaseAuth.instance.currentUser;
    final ownerUid = data['ownerUid'];
    final displayName = currentUser?.displayName ?? currentUser?.email ?? 'Anonymous';

    if (ownerUid == currentUser?.uid) {
      _showMessage('You cannot join your own event.');
      return;
    }

    final currentPeople = data['peopleCount'] ?? 0;
    final signups = List<String>.from(data['signups'] ?? []);

    if (!signups.contains(displayName)) {
      signups.add(displayName);
    }

    if (currentPeople > 1) {
      await eventRef.update({'peopleCount': currentPeople - 1, 'signups': signups});
    } else {
      if (ownerUid != null) {
        final userSnapshot = await _database.child('users/$ownerUid').get();
        final phone = userSnapshot.child('phone').value;
        if (phone != null && mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Event Full!'),
              content: Text('Contact: $phone'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
        }
      }
      await eventRef.remove();
    }
  }

  void _showMessage(String message) {
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
        title: const Text('Plus1'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildEventForm(),
            const SizedBox(height: 20),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }

  Widget _buildEventForm() {
    return Column(
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
      ],
    );
  }

  Widget _buildEventList() {
    if (_events.isEmpty) {
      return const Center(child: Text('No events found'));
    }
    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return _buildEventTile(event);
      },
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final isOwner = event['ownerUid'] == FirebaseAuth.instance.currentUser?.uid;
    final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(eventTime));
    final isStartingSoon = eventTime - DateTime.now().millisecondsSinceEpoch <= 10 * 60 * 1000;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(event['eventName'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${event['peopleCount']} people needed'),
                  Text('At: $formattedTime'),
                  if (isStartingSoon)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _buildCountdownText(eventTime),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  _buildSignupsSection(event),
                ],
              ),
              trailing: isOwner ? _buildDeleteButton(event) : _buildJoinButton(event),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupsSection(Map<String, dynamic> event) {
    final key = event['key'];
    final expanded = _expandedEvents.contains(key);
    final signups = List<String>.from(event['signups'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedEvents.remove(key);
              } else {
                _expandedEvents.add(key);
              }
            });
          },
          child: Row(
            children: [
              const Text('Signups:', style: TextStyle(fontWeight: FontWeight.bold)),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var signup in signups) Text(signup),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeleteButton(Map<String, dynamic> event) {
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.red),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Event?'),
            content: const Text('Are you sure you want to delete this event?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _database.child('events/${event['key']}').remove();
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinButton(Map<String, dynamic> event) {
    return ElevatedButton(
      onPressed: (event['peopleCount'] > 0) ? () => _joinEvent(event) : null,
      child: const Text('Join'),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
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
