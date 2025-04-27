import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  _EventScreenState createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _eventController = TextEditingController();
  final _peopleController = TextEditingController();
  final _database = FirebaseDatabase.instance.ref(); // Firebase Realtime Database instance

  final List<Map<dynamic, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();

    // Listen to changes in the database in real-time
    _database.child('events').onChildAdded.listen((event) {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (eventData != null) {
        setState(() {
          _events.add(eventData);
        });
      }
    });

    _database.child('events').onChildChanged.listen((event) {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (eventData != null) {
        final index = _events.indexWhere((e) => e['id'] == eventData['id']);
        if (index != -1) {
          setState(() {
            _events[index] = eventData;
          });
        }
      }
    });

    _database.child('events').onChildRemoved.listen((event) {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (eventData != null) {
        setState(() {
          _events.removeWhere((e) => e['id'] == eventData['id']);
        });
      }
    });
  }

  void _addEvent() {
    final eventName = _eventController.text.trim();
    final peopleCount = int.tryParse(_peopleController.text.trim()) ?? 0;

    if (eventName.isNotEmpty && peopleCount > 0) {
      final eventData = {
        'eventName': eventName,
        'peopleCount': peopleCount,
        'id': DateTime.now().toString(), // Unique ID based on timestamp
      };
      _database.child('events').push().set(eventData);
      _eventController.clear();
      _peopleController.clear();
    }
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
              onPressed: _addEvent,
              child: const Text('Add Event'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return ListTile(
                    title: Text(event['eventName']),
                    subtitle: Text('${event['peopleCount']} people needed'),
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
