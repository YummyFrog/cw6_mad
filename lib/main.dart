import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Task List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginScreen()
          : const TaskListScreen(),
    );
  }
}

class Task {
  String? id; // Firebase document ID
  String name;
  bool isCompleted;
  List<SubTask> subTasks;
  DateTime createdAt;

  Task({
    this.id,
    required this.name,
    this.isCompleted = false,
    List<SubTask>? subTasks,
    DateTime? createdAt,
  })  : subTasks = subTasks ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      name: data['name'],
      isCompleted: data['isCompleted'],
      subTasks: (data['subTasks'] as List? ?? []).map((subTask) => SubTask.fromMap(subTask)).toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'subTasks': subTasks.map((subTask) => subTask.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class SubTask {
  String timeFrame;
  String description;
  bool isCompleted;

  SubTask({
    required this.timeFrame,
    required this.description,
    this.isCompleted = false,
  });

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      timeFrame: map['timeFrame'],
      description: map['description'],
      isCompleted: map['isCompleted'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timeFrame': timeFrame,
      'description': description,
      'isCompleted': isCompleted,
    };
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late CollectionReference tasksCollection;

  @override
  void initState() {
    super.initState();
    tasksCollection = _firestore.collection('tasks');
  }

  Future<void> _addTask() async {
    if (_taskController.text.isNotEmpty) {
      final newTask = Task(name: _taskController.text);
      await tasksCollection.add(newTask.toFirestore());
      _taskController.clear();
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    await tasksCollection.doc(task.id).update({
      'isCompleted': !task.isCompleted,
    });
  }

  Future<void> _deleteTask(String taskId) async {
    await tasksCollection.doc(taskId).delete();
  }

  Future<void> _addSubTask(Task task, String timeFrame, String description) async {
    final newSubTask = SubTask(timeFrame: timeFrame, description: description);
    final updatedSubTasks = [...task.subTasks, newSubTask];
    
    await tasksCollection.doc(task.id).update({
      'subTasks': updatedSubTasks.map((st) => st.toMap()).toList(),
    });
  }

  Future<void> _toggleSubTaskCompletion(Task task, int subTaskIndex) async {
    final updatedSubTasks = List<SubTask>.from(task.subTasks);
    updatedSubTasks[subTaskIndex].isCompleted = !updatedSubTasks[subTaskIndex].isCompleted;
    
    await tasksCollection.doc(task.id).update({
      'subTasks': updatedSubTasks.map((st) => st.toMap()).toList(),
    });
  }

  Future<void> _deleteSubTask(Task task, int subTaskIndex) async {
    final updatedSubTasks = List<SubTask>.from(task.subTasks);
    updatedSubTasks.removeAt(subTaskIndex);
    
    await tasksCollection.doc(task.id).update({
      'subTasks': updatedSubTasks.map((st) => st.toMap()).toList(),
    });
  }

  void _showAddSubTaskDialog(Task task) {
    final timeController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Sub-Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time Frame (e.g., 9am-10am)',
                ),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Task Description',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (timeController.text.isNotEmpty && descController.text.isNotEmpty) {
                  await _addSubTask(task, timeController.text, descController.text);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Task List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Text input field
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'Enter task name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addTask(),
            ),
            const SizedBox(height: 10),
            // Add button
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Add Main Task'),
            ),
            const SizedBox(height: 20),
            // Task list from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: tasksCollection.orderBy('createdAt').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data!.docs
                      .map((doc) => Task.fromFirestore(doc))
                      .toList();

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        child: ExpansionTile(
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) => _toggleTaskCompletion(task),
                          ),
                          title: Text(
                            task.name,
                            style: TextStyle(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTask(task.id!),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Sub-Tasks:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextButton(
                                        onPressed: () => _showAddSubTaskDialog(task),
                                        child: const Text('+ Add Sub-Task'),
                                      ),
                                    ],
                                  ),
                                  if (task.subTasks.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('No sub-tasks added yet'),
                                    )
                                  else
                                    ...task.subTasks.map((subTask) {
                                      final subTaskIndex = task.subTasks.indexOf(subTask);
                                      return ListTile(
                                        leading: Checkbox(
                                          value: subTask.isCompleted,
                                          onChanged: (_) => _toggleSubTaskCompletion(task, subTaskIndex),
                                        ),
                                        title: Text(
                                          '${subTask.timeFrame}: ${subTask.description}',
                                          style: TextStyle(
                                            decoration: subTask.isCompleted
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _deleteSubTask(task, subTaskIndex),
                                        ),
                                      );
                                    }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TaskListScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Login Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () async {
                await _login(
                  _emailController.text,
                  _passwordController.text,
                );
              },
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text('Create an Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _register(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TaskListScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Registration Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () async {
                await _register(
                  _emailController.text,
                  _passwordController.text,
                );
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
