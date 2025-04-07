import 'package:flutter/material.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Task List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TaskListScreen(),
    );
  }
}

class Task {
  String name;
  bool isCompleted;
  List<SubTask> subTasks;

  Task({
    required this.name,
    this.isCompleted = false,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];
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
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final List<Task> _tasks = [];

  void _addTask() {
    if (_taskController.text.isNotEmpty) {
      setState(() {
        _tasks.add(Task(name: _taskController.text));
        _taskController.clear();
      });
    }
  }

  void _addSubTask(Task task, String timeFrame, String description) {
    setState(() {
      task.subTasks.add(SubTask(
        timeFrame: timeFrame,
        description: description,
      ));
    });
  }

  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });
  }

  void _toggleSubTaskCompletion(Task task, int subTaskIndex) {
    setState(() {
      task.subTasks[subTaskIndex].isCompleted =
          !task.subTasks[subTaskIndex].isCompleted;
    });
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _deleteSubTask(Task task, int subTaskIndex) {
    setState(() {
      task.subTasks.removeAt(subTaskIndex);
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
              onPressed: () {
                if (timeController.text.isNotEmpty &&
                    descController.text.isNotEmpty) {
                  _addSubTask(task, timeController.text, descController.text);
                  Navigator.pop(context);
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
        title: const Text('Advanced Task List'),
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
            // Task list
            Expanded(
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Card(
                    child: ExpansionTile(
                      leading: Checkbox(
                        value: task.isCompleted,
                        onChanged: (_) => _toggleTaskCompletion(index),
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
                        onPressed: () => _deleteTask(index),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                  final subTaskIndex =
                                      task.subTasks.indexOf(subTask);
                                  return ListTile(
                                    leading: Checkbox(
                                      value: subTask.isCompleted,
                                      onChanged: (_) =>
                                          _toggleSubTaskCompletion(
                                              task, subTaskIndex),
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
                                      icon: const Icon(Icons.delete, size: 20),
                                      onPressed: () => _deleteSubTask(
                                          task, subTaskIndex),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }
}