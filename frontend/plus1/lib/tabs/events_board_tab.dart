import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../components/create_event_modal.dart';

class EventsBoardTab extends StatefulWidget {
  final ScrollController? scrollController;
  
  const EventsBoardTab({super.key, this.scrollController});

  @override
  _EventsBoardTabState createState() => _EventsBoardTabState();
}

class _EventsBoardTabState extends State<EventsBoardTab> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  late StreamSubscription<DatabaseEvent> _eventsSubscription;
  Timer? _refreshTimer;
  final _database = FirebaseDatabase.instance.ref();
  
  // Color constants
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color textColor = Colors.black87;
  static const Color lightGray = Color(0xFFF2F2F2);

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
    
    // Refresh UI every minute to update countdown displays
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }
  
  void _subscribeToEvents() {
    // Subscribe to events node in Realtime Database
    print("DEBUG: Subscribing to events with ref: ${_database.child('events').path}");
    
    _eventsSubscription = _database.child('events').onValue.listen((event) {
      print("DEBUG: Received events update from Firebase");
      
      if (mounted) {
        setState(() {
          _events = [];
          final now = DateTime.now().millisecondsSinceEpoch;
          
          if (event.snapshot.value != null) {
            print("DEBUG: Event snapshot value is not null");
            
            // Safe conversion of the snapshot value to a Map
            Map<dynamic, dynamic>? eventsMap;
            try {
              eventsMap = event.snapshot.value as Map<dynamic, dynamic>;
              print("DEBUG: Events map contains ${eventsMap.length} events");
            } catch (e) {
              print("ERROR: Could not convert snapshot value to Map: $e");
              print("DEBUG: Snapshot value type: ${event.snapshot.value.runtimeType}");
              _isLoading = false;
              return;
            }
            
            eventsMap.forEach((key, value) {
              try {
                if (value is Map) {
                  final eventData = Map<String, dynamic>.from(value as Map);
                  
                  // Add the database key to the event data
                  eventData['key'] = key;
                  
                  // Safely handle event time
                  int eventTime;
                  try {
                    eventTime = int.parse(eventData['eventTime'].toString());
                  } catch (e) {
                    print("ERROR: Invalid eventTime for event $key: ${eventData['eventTime']}");
                    eventTime = 0;
                  }
                  
                  print("DEBUG: Event ${eventData['eventName']} time is $eventTime, now is $now");
                  
                  if (eventTime > now) {
                    // Handle signups properly (might be null)
                    if (!eventData.containsKey('signups') || eventData['signups'] == null) {
                      eventData['signups'] = [];
                    }
                    
                    // Add to our events list
                    _events.add(eventData);
                    print("DEBUG: Added event ${eventData['eventName']} to the list");
                  } else {
                    print("DEBUG: Ignored past event ${eventData['eventName']}");
                  }
                } else {
                  print("DEBUG: Skipped invalid event value (not a Map): $value");
                }
              } catch (e) {
                print("ERROR processing event $key: $e");
              }
            });
            
            // Sort events by time (earliest first)
            _events.sort((a, b) {
              int timeA = int.tryParse(a['eventTime'].toString()) ?? 0;
              int timeB = int.tryParse(b['eventTime'].toString()) ?? 0;
              return timeA.compareTo(timeB);
            });
            
            print("DEBUG: Final events list contains ${_events.length} events");
          } else {
            print("DEBUG: Event snapshot value is null");
          }
          
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('ERROR subscribing to events: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Show a message to the user that there was an error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading events: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    });
  }

  void _onEventCreated() {
    // Refresh events after creating a new one
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _joinEvent(Map<String, dynamic> event) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showAuthRequiredDialog('join an event');
      return;
    }
    
    final String eventKey = event['key'];
    final int peopleCount = int.tryParse(event['peopleCount'].toString()) ?? 0;
    final displayName = currentUser.displayName ?? currentUser.email ?? 'Anonymous';
    
    // Check if user is the event owner
    if (event['ownerUid'] == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot join your own event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Get current signups
    final eventRef = _database.child('events/$eventKey');
    final eventSnapshot = await eventRef.get();
    
    if (!eventSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event no longer exists'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final eventData = Map<String, dynamic>.from(eventSnapshot.value as Map);
    List<String> signups = [];
    
    if (eventData.containsKey('signups') && eventData['signups'] != null) {
      if (eventData['signups'] is List) {
        signups = List<String>.from(eventData['signups']);
      }
    }
    
    // Check if user already signed up
    if (signups.contains(displayName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already signed up for this event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check if event is full
    if (peopleCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event is already full'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Add user to signups
      signups.add(displayName);
      
      // Update event in database
      await eventRef.update({
        'peopleCount': peopleCount - 1,
        'signups': signups,
      });
      
      // Add to user's signups
      final eventId = event['id'] ?? eventKey;
      await _database.child('users/${currentUser.uid}/signups/$eventId').set(true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined the event!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error joining event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join event: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _leaveEvent(Map<String, dynamic> event) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showAuthRequiredDialog('leave an event');
      return;
    }
    
    final String eventKey = event['key'];
    final displayName = currentUser.displayName ?? currentUser.email ?? 'Anonymous';
    
    // Get current signups
    final eventRef = _database.child('events/$eventKey');
    final eventSnapshot = await eventRef.get();
    
    if (!eventSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event no longer exists'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final eventData = Map<String, dynamic>.from(eventSnapshot.value as Map);
    List<String> signups = [];
    
    if (eventData.containsKey('signups') && eventData['signups'] != null) {
      if (eventData['signups'] is List) {
        signups = List<String>.from(eventData['signups']);
      }
    }
    
    // Check if user is signed up
    if (!signups.contains(displayName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not signed up for this event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Remove user from signups
      signups.remove(displayName);
      
      // Update event in database
      final int peopleCount = int.tryParse(eventData['peopleCount'].toString()) ?? 0;
      await eventRef.update({
        'peopleCount': peopleCount + 1,
        'signups': signups,
      });
      
      // Remove from user's signups
      final eventId = event['id'] ?? eventKey;
      await _database.child('users/${currentUser.uid}/signups/$eventId').remove();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully left the event'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error leaving event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave event: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAuthRequiredDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: Text('You need to be signed in to $action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCreateEventModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEventModal(
        onEventCreated: _onEventCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Create event form at the top
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CREATE EVENT',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _showCreateEventModal,
                  icon: const Icon(Icons.add),
                  label: const Text('CREATE NEW EVENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentYellow,
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          const Divider(height: 1, thickness: 1),
          
          // Event list
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty 
                    ? _buildEmptyState() 
                    : _buildEventsList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No events scheduled',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an event and invite others to join!',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateEventModal,
            icon: const Icon(Icons.add),
            label: const Text('CREATE EVENT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentYellow,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventsList() {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(eventTime)
    );
    final isCurrentUserEvent = event['ownerUid'] == FirebaseAuth.instance.currentUser?.uid;
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
                  isCurrentUserEvent
                      ? _buildDeleteButton(event)
                      : _buildJoinButton(event),
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
              _buildSignupsSection(event),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(Map<String, dynamic> event) {
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
                    await _database.child('events/${event['key']}').remove();
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

  Widget _buildJoinButton(Map<String, dynamic> event) {
    final peopleCount = int.tryParse(event['peopleCount'].toString()) ?? 0;
    final isDisabled = peopleCount <= 0;
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

  Widget _buildSignupsSection(Map<String, dynamic> event) {
    final signups = event['signups'] ?? [];
    List<String> signupsList = [];
    
    if (signups is List) {
      signupsList = List<String>.from(signups);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: lightGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Signups',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          signupsList.isEmpty
              ? const Text('No signups yet', style: TextStyle(fontStyle: FontStyle.italic))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: signupsList.map((signup) => Padding(
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

  @override
  void dispose() {
    _eventsSubscription.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
} 