import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventsBoardTab extends StatefulWidget {
  const EventsBoardTab({super.key});

  @override
  _EventsBoardTabState createState() => _EventsBoardTabState();
}

class _EventsBoardTabState extends State<EventsBoardTab> {
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
  
  // Color constants
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color textColor = Colors.black87;
  static const Color lightGray = Color(0xFFF2F2F2);

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: fiveMinutesLater.hour, minute: fiveMinutesLater.minute),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: primaryBlue,
              ),
            ),
            child: child!,
          );
        },
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
    final eventId = DateTime.now().toIso8601String();

    if (eventName.isNotEmpty && peopleCount > 0 && _selectedDateTime != null && uid != null) {
      final eventData = {
        'eventId': eventId,
        'eventName': eventName,
        'peopleCount': peopleCount,
        'eventTime': _selectedDateTime!.millisecondsSinceEpoch,
        'ownerUid': uid,
        'signups': [],
      };
      _database.child('events').push().set(eventData);

      // Add this event to the user's created events
      _database.child('users/$uid/createdEvents/$eventId').set(true);

      _eventController.clear();
      _peopleController.clear();
      _selectedDateTime = null;
    } else {
      _showMessage('Please complete all fields correctly.');
    }
  }

  Future<void> _joinEvent(Map<String, dynamic> event) async {
    final eventKey = event['key'];
    final eventId = event['eventId'];
    final eventRef = _database.child('events/$eventKey');
    final snapshot = await eventRef.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final uid = currentUser.uid;
    final ownerUid = data['ownerUid'];
    final displayName = currentUser.displayName ?? currentUser.email ?? 'Anonymous';

    if (ownerUid == uid) {
      _showMessage('You cannot join your own event.');
      return;
    }

    final currentPeople = data['peopleCount'] ?? 0;
    final signups = List<String>.from(data['signups'] ?? []);

    if (!signups.contains(displayName)) {
      signups.add(displayName);
    }

    if (currentPeople > 1) {
      // Update the event with new signup
      await eventRef.update({'peopleCount': currentPeople - 1, 'signups': signups});
      
      // Add this event to user's signups
      await _database.child('users/$uid/signups/$eventId').set(true);
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
      // Add this event to user's signups before it's removed
      await _database.child('users/$uid/signups/$eventId').set(true);
      await eventRef.remove();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryBlue,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event creation form card
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_circle_outline, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'CREATE EVENT',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStyledEventForm(),
                ],
              ),
            ),
          ),
          // Events list heading
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event_note, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              const Text(
                'AVAILABLE EVENTS',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Events list
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: accentYellow.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_busy,
                            size: 48,
                            color: primaryBlue.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No events found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a new event above',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildStyledEventTile(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledEventForm() {
    return Column(
      children: [
        TextField(
          controller: _eventController,
          decoration: InputDecoration(
            labelText: 'Event Name',
            prefixIcon: const Icon(Icons.celebration, color: primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: primaryBlue),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _peopleController,
          decoration: InputDecoration(
            labelText: 'People Needed',
            prefixIcon: const Icon(Icons.people, color: primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: primaryBlue),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.calendar_month),
          label: Text(
            _selectedDateTime == null
                ? 'Pick Event Time'
                : 'Event Time: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime!.toLocal())}',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addEvent,
            icon: const Icon(Icons.add_circle),
            label: const Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentYellow,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyledEventTile(Map<String, dynamic> event) {
    final isOwner = event['ownerUid'] == FirebaseAuth.instance.currentUser?.uid;
    final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(eventTime));
    final isStartingSoon = eventTime - DateTime.now().millisecondsSinceEpoch <= 10 * 60 * 1000;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, lightGray],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event['eventName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                  isOwner
                      ? _buildStyledDeleteButton(event)
                      : _buildStyledJoinButton(event),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${event['peopleCount']} people needed',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    'At: $formattedTime',
                    style: const TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (isStartingSoon)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        _buildCountdownText(eventTime),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildStyledSignupsSection(event),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledSignupsSection(Map<String, dynamic> event) {
    final key = event['key'];
    final expanded = _expandedEvents.contains(key);
    final signups = List<String>.from(event['signups'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: lightGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedEvents.remove(key);
                } else {
                  _expandedEvents.add(key);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Signups',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: signups.isEmpty
                    ? [const Text('No signups yet', style: TextStyle(fontStyle: FontStyle.italic))]
                    : signups.map((signup) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: primaryBlue),
                            const SizedBox(width: 4),
                            Text(signup),
                          ],
                        ),
                      )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStyledDeleteButton(Map<String, dynamic> event) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: Colors.red.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Event?'),
              content: const Text('Are you sure you want to delete this event?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: primaryBlue)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final eventId = event['eventId'];

                    if (uid != null && eventId != null) {
                      // Remove from user's created events
                      await _database.child('users/$uid/createdEvents/$eventId').remove();
                      
                      // Remove the event
                      await _database.child('events/${event['key']}').remove();
                    }
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.delete, color: Colors.red, size: 20),
        ),
      ),
    );
  }

  Widget _buildStyledJoinButton(Map<String, dynamic> event) {
    final isDisabled = event['peopleCount'] <= 0;
    return ElevatedButton(
      onPressed: isDisabled ? null : () => _joinEvent(event),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.withOpacity(0.3),
        disabledForegroundColor: Colors.grey.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text('Join'),
    );
  }
} 