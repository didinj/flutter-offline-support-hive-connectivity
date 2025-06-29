import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box box;
  late StreamSubscription<List<ConnectivityResult>> subscription;
  bool isOnline = true;

  final titleController = TextEditingController();
  final contentController = TextEditingController();

  Future<void> syncUnsyncedNotes() async {
    final notes = box.values.toList();

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];

      if (note is Map && note['isSynced'] == false) {
        final response = await http.post(
          Uri.parse('https://example.com/api/notes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': note['title'],
            'content': note['content'],
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Update isSynced status
          final updatedNote = {
            'title': note['title'],
            'content': note['content'],
            'isSynced': true,
          };
          box.putAt(i, updatedNote);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    box = Hive.box('myBox');
    checkConnectivity();
    listenToConnectivityChanges();
  }

  void checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  void listenToConnectivityChanges() {
    subscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

      final nowOnline = result != ConnectivityResult.none;
      setState(() {
        isOnline = nowOnline;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nowOnline ? 'Back Online' : 'You are Offline'),
          backgroundColor: nowOnline ? Colors.green : Colors.red,
        ),
      );

      if (nowOnline) {
        syncUnsyncedNotes();
      }
    });
  }

  void addNote(String title, String content) {
    final note = {'title': title, 'content': content};
    box.add(note);
    titleController.clear();
    contentController.clear();
    setState(() {});
  }

  @override
  void dispose() {
    subscription.cancel();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = box.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Notes App'),
        backgroundColor: isOnline ? Colors.green : Colors.grey,
      ),
      body: Column(
        children: [
          if (!isOnline)
            Container(
              color: Colors.red,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Offline Mode',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index] as Map;
                final isSynced = note['isSynced'] == true;

                return ListTile(
                  leading: Icon(
                    isSynced ? Icons.cloud_done : Icons.cloud_off,
                    color: isSynced ? Colors.green : Colors.grey,
                  ),
                  title: Text(note['title']),
                  subtitle: Text(note['content']),
                  trailing: isSynced
                      ? const Text(
                    'Synced',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  )
                      : const Text(
                    'Offline',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty &&
                        contentController.text.isNotEmpty) {
                      addNote(titleController.text, contentController.text);
                    }
                  },
                  child: const Text('Add Note'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}