import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EntryListScreen(),
    );
  }
}

class EntryListScreen extends StatefulWidget {
  @override
  _EntryListScreenState createState() => _EntryListScreenState();
}

class _EntryListScreenState extends State<EntryListScreen> {
  final List<String> _entries = []; // List to hold added entries
  final TextEditingController _controller = TextEditingController();

  void _addEntry() {
    final entry = _controller.text.trim();
    if (entry.isNotEmpty) {
      setState(() {
        _entries.add(entry);
      });
      _controller.clear(); // Clear text field after adding
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Entry List'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Enter a new entry'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addEntry,
              child: Text('Add Entry'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_entries[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: Icon(Icons.add),
      ),
    );
  }
}
