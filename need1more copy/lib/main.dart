import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // Import the generated Firebase options
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use the options generated
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Bulletin Board',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: EventScreen(),
    );
  }
}

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
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?; // Cast to Map
      if (eventData != null) {
        setState(() {
          _events.add(eventData);
        });
      }
    });

    _database.child('events').onChildChanged.listen((event) {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?; // Cast to Map
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
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?; // Cast to Map
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
      _database.child('events').push().set(eventData); // Add event to Firebase
      _eventController.clear();
      _peopleController.clear();
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Bulletin Board'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _eventController,
              decoration: InputDecoration(labelText: 'Event Name'),
            ),
            TextField(
              controller: _peopleController,
              decoration: InputDecoration(labelText: 'People Needed'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addEvent,
              child: Text('Add Event'),
            ),
            SizedBox(height: 20),
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
