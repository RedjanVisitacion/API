import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<dynamic> users = [];
  bool isLoading = true;
  String? error;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  String? _editingUserId;
  String? _editingUserSource;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/users'),
      );

      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load users';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    if (user != null) {
      _nameController.text = user['name'] ?? '';
      _genderController.text = user['gender'] ?? '';
      _editingUserId = user['idno']?.toString() ?? user['_id']?.toString();
      _editingUserSource = user.containsKey('idno') ? 'MySQL' : 'MongoDB';
    } else {
      _nameController.clear();
      _genderController.clear();
      _editingUserId = null;
      _editingUserSource = null;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user == null ? 'Add User' : 'Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _genderController,
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty && _genderController.text.isNotEmpty) {
                _saveUser();
                Navigator.pop(context);
              }
            },
            child: Text(user == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUser() async {
    try {
      final userData = {
        'name': _nameController.text,
        'gender': _genderController.text,
      };

      if (_editingUserId != null) {
        // Update existing user
        final response = await http.put(
          Uri.parse('http://127.0.0.1:8000/users/$_editingUserId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(userData),
        );
      } else {
        // Create new user
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(userData),
        );
      }

      fetchUsers(); // Refresh the list
    } catch (e) {
      setState(() {
        error = 'Error saving user: $e';
      });
    }
  }

  Future<void> _deleteUser(String userId, String source) async {
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/users/$userId?source=$source'),
      );

      if (response.statusCode == 200) {
        fetchUsers(); // Refresh the list
      } else {
        setState(() {
          error = 'Failed to delete user';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error deleting user: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Student Users'),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : error != null
                ? Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  )
                : users.isEmpty
                    ? const Text('No users found')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(
                              label: Text('Source', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            DataColumn(
                              label: Text('ID', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            DataColumn(
                              label: Text('Name', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            DataColumn(
                              label: Text('Gender', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            DataColumn(
                              label: Text('Actions', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                          rows: users.asMap().entries.map((entry) {
                            final user = entry.value;
                            final source = user.containsKey('idno') ? 'MySQL' : 'MongoDB';
                            final userId = user['idno']?.toString() ?? user['_id']?.toString() ?? 'No ID';
                            final userName = user['name']?.toString() ?? 'No name';
                            final userGender = user['gender']?.toString() ?? 'No gender';
                            
                            return DataRow(
                              color: MaterialStateProperty.all(
                                source == 'MySQL' 
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1)
                              ),
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: source == 'MySQL' 
                                        ? Colors.blue
                                        : Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      source,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(userId)),
                                DataCell(
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DataCell(Text(userGender)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showUserDialog(user: user),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteUser(userId, source),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _showUserDialog(),
            tooltip: 'Add User',
            backgroundColor: Colors.green,
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: fetchUsers,
            tooltip: 'Refresh',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
