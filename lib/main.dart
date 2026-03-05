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
      debugShowCheckedModeBanner: false,
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
  String _selectedSource = 'MySQL';

  String? _extractApiError(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
      return response.body.isNotEmpty ? response.body : null;
    } catch (_) {
      return response.body.isNotEmpty ? response.body : null;
    }
  }

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
      _selectedSource = _editingUserSource ?? 'MySQL';
    } else {
      _nameController.clear();
      _genderController.clear();
      _editingUserId = null;
      _editingUserSource = null;
      _selectedSource = 'MySQL';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user == null ? 'Add User' : 'Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSource,
              decoration: const InputDecoration(labelText: 'Database'),
              items: const [
                DropdownMenuItem(value: 'MySQL', child: Text('MySQL')),
                DropdownMenuItem(value: 'MongoDB', child: Text('MongoDB')),
              ],
              onChanged: user == null
                  ? (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedSource = value;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: (_genderController.text.isNotEmpty ? _genderController.text : null),
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) {
                _genderController.text = value ?? '';
              },
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
          Uri.parse(
              'http://127.0.0.1:8000/users/$_editingUserId?source=${_editingUserSource ?? 'MySQL'}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(userData),
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final msg = _extractApiError(response) ?? 'Failed to update user';
          setState(() {
            error = msg;
          });
          return;
        }
      } else {
        // Create new user
        userData['source'] = _selectedSource;
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(userData),
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final msg = _extractApiError(response) ?? 'Failed to create user';
          setState(() {
            error = msg;
          });
          return;
        }
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
        final msg = _extractApiError(response) ?? 'Failed to delete user';
        setState(() {
          error = msg;
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
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const fabSpace = 92.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D5DF6), Color(0xFFB85CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Users',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage users from MySQL and MongoDB',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + fabSpace + bottomInset),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                            ? Center(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : users.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No users found',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrow = constraints.maxWidth < 560;

                                      if (isNarrow) {
                                        return ListView.separated(
                                          itemCount: users.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final user = users[index];
                                            final source = user.containsKey('idno')
                                                ? 'MySQL'
                                                : 'MongoDB';
                                            final userId = user['idno']?.toString() ??
                                                user['_id']?.toString() ??
                                                'No ID';
                                            final userName =
                                                user['name']?.toString() ?? 'No name';
                                            final userGender =
                                                user['gender']?.toString() ?? 'No gender';

                                            final badgeColor = source == 'MySQL'
                                                ? const Color(0xFF2F6BFF)
                                                : const Color(0xFF18A957);
                                            final cardTint = source == 'MySQL'
                                                ? const Color(0xFFEFF4FF)
                                                : const Color(0xFFEEFFF3);

                                            return Container(
                                              decoration: BoxDecoration(
                                                color: cardTint,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.black.withOpacity(0.06),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 10, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: badgeColor,
                                                            borderRadius:
                                                                BorderRadius.circular(999),
                                                          ),
                                                          child: Text(
                                                            source,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        IconButton(
                                                          onPressed: () =>
                                                              _showUserDialog(user: user),
                                                          icon: Icon(Icons.edit,
                                                              color: scheme.primary),
                                                          tooltip: 'Edit',
                                                        ),
                                                        IconButton(
                                                          onPressed: () =>
                                                              _deleteUser(userId, source),
                                                          icon: const Icon(Icons.delete,
                                                              color: Colors.red),
                                                          tooltip: 'Delete',
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      userName,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF2D2A3A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'ID: $userId',
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.black
                                                                  .withOpacity(0.65),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Text(
                                                          'Gender: $userGender',
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.black
                                                                .withOpacity(0.65),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      }

                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 12 + fabSpace + bottomInset,
                                          ),
                                          child: DataTable(
                                            headingRowColor: MaterialStateProperty.all(
                                              const Color(0xFFF6F2FF),
                                            ),
                                            headingTextStyle: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF2D2A3A),
                                            ),
                                            columns: const [
                                              DataColumn(label: Text('Source')),
                                              DataColumn(label: Text('ID')),
                                              DataColumn(label: Text('Name')),
                                              DataColumn(label: Text('Gender')),
                                              DataColumn(label: Text('Actions')),
                                            ],
                                            rows: users.asMap().entries.map((entry) {
                                              final user = entry.value;
                                              final source = user.containsKey('idno')
                                                  ? 'MySQL'
                                                  : 'MongoDB';
                                              final userId = user['idno']?.toString() ??
                                                  user['_id']?.toString() ??
                                                  'No ID';
                                              final userName =
                                                  user['name']?.toString() ?? 'No name';
                                              final userGender =
                                                  user['gender']?.toString() ?? 'No gender';

                                              final rowColor = source == 'MySQL'
                                                  ? const Color(0xFFEFF4FF)
                                                  : const Color(0xFFEEFFF3);
                                              final badgeColor = source == 'MySQL'
                                                  ? const Color(0xFF2F6BFF)
                                                  : const Color(0xFF18A957);

                                              return DataRow(
                                                color: MaterialStateProperty.all(rowColor),
                                                cells: [
                                                  DataCell(
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: badgeColor,
                                                        borderRadius: BorderRadius.circular(999),
                                                      ),
                                                      child: Text(
                                                        source,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(Text(userId)),
                                                  DataCell(
                                                    Text(
                                                      userName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(Text(userGender)),
                                                  DataCell(
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            Icons.edit,
                                                            color: scheme.primary,
                                                          ),
                                                          onPressed: () =>
                                                              _showUserDialog(user: user),
                                                          tooltip: 'Edit',
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.delete,
                                                            color: Colors.red,
                                                          ),
                                                          onPressed: () =>
                                                              _deleteUser(userId, source),
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
                                      );
                                    },
                                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _showUserDialog(),
            tooltip: 'Add User',
            backgroundColor: const Color(0xFF18A957),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: fetchUsers,
            tooltip: 'Refresh',
            backgroundColor: const Color(0xFF6D5DF6),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
