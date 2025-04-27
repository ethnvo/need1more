import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  String _status = 'Ready to test';
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    _isLoading 
                        ? const CircularProgressIndicator() 
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Auth info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Authentication:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('User: ${_auth.currentUser?.email ?? 'Not signed in'}'),
                    Text('User ID: ${_auth.currentUser?.uid ?? 'N/A'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test actions
            Row(
              children: [
                ElevatedButton(
                  onPressed: _testCreateEvent,
                  child: const Text('Create Test Event'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _listEvents,
                  child: const Text('List Events'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Event list
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Events:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return ListTile(
                              title: Text(event['eventName'] ?? 'No name'),
                              subtitle: Text('People needed: ${event['peopleCount'] ?? 'Unknown'}'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testCreateEvent() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating test event...';
    });

    try {
      // Check if user is logged in
      if (_auth.currentUser == null) {
        setState(() {
          _status = 'Error: User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Create test event data
      final eventData = {
        'eventName': 'Test Event ${DateTime.now().millisecondsSinceEpoch}',
        'peopleCount': 5,
        'eventTime': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'id': DateTime.now().toIso8601String(),
        'ownerUid': _auth.currentUser!.uid,
        'signups': [],
        'createdAt': ServerValue.timestamp,
      };

      // Log for debugging
      print('DEBUG: Firebase connection state: ${Firebase.app().isAutomaticDataCollectionEnabled}');
      print('DEBUG: Creating test event with data: $eventData');
      print('DEBUG: Database reference path: ${_database.path}');

      // Push to database
      final newEventRef = _database.child('events').push();
      print('DEBUG: New event reference key: ${newEventRef.key}');
      
      await newEventRef.set(eventData);
      
      setState(() {
        _status = 'Event created successfully with key: ${newEventRef.key}';
        _isLoading = false;
      });
      
      // Refresh events list
      _listEvents();
    } catch (e) {
      print('ERROR creating test event: $e');
      setState(() {
        _status = 'Error creating event: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _listEvents() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading events...';
    });

    try {
      // Get events from database
      final eventsSnapshot = await _database.child('events').get();
      
      if (!eventsSnapshot.exists) {
        setState(() {
          _status = 'No events found';
          _events = [];
          _isLoading = false;
        });
        return;
      }
      
      final eventsData = eventsSnapshot.value as Map<dynamic, dynamic>?;
      
      if (eventsData == null) {
        setState(() {
          _status = 'Events data is null';
          _events = [];
          _isLoading = false;
        });
        return;
      }
      
      List<Map<String, dynamic>> eventsList = [];
      
      eventsData.forEach((key, value) {
        if (value is Map) {
          final eventData = Map<String, dynamic>.from(value as Map);
          eventData['key'] = key;
          eventsList.add(eventData);
        }
      });
      
      // Sort by time
      eventsList.sort((a, b) {
        int timeA = int.tryParse(a['eventTime'].toString()) ?? 0;
        int timeB = int.tryParse(b['eventTime'].toString()) ?? 0;
        return timeA.compareTo(timeB);
      });
      
      setState(() {
        _events = eventsList;
        _status = 'Loaded ${eventsList.length} events';
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR listing events: $e');
      setState(() {
        _status = 'Error listing events: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(String? eventKey) async {
    if (eventKey == null) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Deleting event...';
    });

    try {
      await _database.child('events/$eventKey').remove();
      
      setState(() {
        _status = 'Event deleted successfully';
        _isLoading = false;
      });
      
      // Refresh events list
      _listEvents();
    } catch (e) {
      print('ERROR deleting event: $e');
      setState(() {
        _status = 'Error deleting event: $e';
        _isLoading = false;
      });
    }
  }
} 