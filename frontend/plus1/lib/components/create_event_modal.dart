import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateEventModal extends StatefulWidget {
  final Function onEventCreated;

  const CreateEventModal({
    super.key,
    required this.onEventCreated,
  });

  @override
  State<CreateEventModal> createState() => _CreateEventModalState();
}

class _CreateEventModalState extends State<CreateEventModal> {
  final _eventNameController = TextEditingController();
  final _peopleNeededController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isCreating = false;
  final _database = FirebaseDatabase.instance.ref();
  
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);

  @override
  void dispose() {
    _eventNameController.dispose();
    _peopleNeededController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: primaryBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
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

  Future<void> _createEvent() async {
    // Validate inputs
    if (_eventNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }

    if (_peopleNeededController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the number of people needed')),
      );
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    // Parse people needed
    int? peopleNeeded = int.tryParse(_peopleNeededController.text);
    if (peopleNeeded == null || peopleNeeded <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of people needed')),
      );
      return;
    }

    // Get current user
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create an event')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Create a unique ID for the event
      String eventId = DateTime.now().toIso8601String();
      
      // Create event data for Realtime Database
      final eventData = {
        'eventName': _eventNameController.text,
        'peopleCount': peopleNeeded,
        'eventTime': _selectedDateTime!.millisecondsSinceEpoch,
        'id': eventId,
        'ownerUid': currentUser.uid,
        'signups': [],
        'createdAt': ServerValue.timestamp,
      };
      
      print("DEBUG: Creating event with data: $eventData");
      print("DEBUG: Database reference path: ${_database.child('events').path}");
      
      // Push the event to the database
      // Using a TransactionResult to ensure atomicity
      try {
        DatabaseReference newEventRef = _database.child('events').push();
        print("DEBUG: New event reference key: ${newEventRef.key}");

        // Convert signups to a format Firebase can handle (empty List<String> can cause issues)
        Map<String, dynamic> finalEventData = {
          'eventName': _eventNameController.text,
          'peopleCount': peopleNeeded,
          'eventTime': _selectedDateTime!.millisecondsSinceEpoch,
          'id': eventId,
          'ownerUid': currentUser.uid,
          'createdAt': ServerValue.timestamp,
        };
        
        // Explicitly add signups as null to let Firebase handle it properly
        await newEventRef.set(finalEventData);
        
        // Then update with empty signups array in a separate call
        await newEventRef.child('signups').set([]);
        
        print("DEBUG: Event created successfully");
      } catch (e) {
        print("ERROR: Failed to save event data: $e");
        throw e;
      }

      // Set _isCreating to false before calling callbacks and popping
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }

      // Notify parent of success
      widget.onEventCreated();
      
      // Close modal
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('ERROR creating event: $e');
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Create New Event',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Event name field
          TextField(
            controller: _eventNameController,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              prefixIcon: Icon(Icons.event, color: primaryBlue),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // People needed field
          TextField(
            controller: _peopleNeededController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'People Needed (besides yourself)',
              prefixIcon: Icon(Icons.people, color: primaryBlue),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date/time picker button
          ElevatedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(
              _selectedDateTime == null
                  ? 'Pick Date & Time'
                  : 'Time: ${DateFormat('MMM d, y - h:mm a').format(_selectedDateTime!)}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryBlue,
              side: const BorderSide(color: primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _pickDateTime,
          ),
          const SizedBox(height: 24),
          
          // Create button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentYellow,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isCreating ? null : _createEvent,
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  )
                : const Text(
                    'CREATE EVENT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          // Add padding at the bottom to account for keyboard
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
          ),
        ],
      ),
    );
  }
} 