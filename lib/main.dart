import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CountdownApp());

class CountdownApp extends StatelessWidget {
  const CountdownApp({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
        title: 'Countdown App',
        theme: ThemeData.dark(),
        home: const CountdownHomePage(),
      );
}

class CountdownEvent {
  String name;
  DateTime target;
  CountdownEvent({required this.name, required this.target});
  Map<String, dynamic> toMap() =>
      {'name': name, 'target': target.toIso8601String()};
  factory CountdownEvent.fromMap(Map<String, dynamic> m) =>
      CountdownEvent(name: m['name'], target: DateTime.parse(m['target']));
}

class CountdownHomePage extends StatefulWidget {
  const CountdownHomePage({super.key});
  @override
  State<CountdownHomePage> createState() => _S();
}

class _S extends State<CountdownHomePage> {
  Map<String, List<CountdownEvent>> cats = {};
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _load();
    Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('event_data');
    if (raw != null) {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        cats = obj.map((k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => CountdownEvent.fromMap(e))
                .toList()));
      });
    }
  }

  Future<void> _save() async {
    await prefs.setString('event_data',
        jsonEncode(cats.map((k, v) => MapEntry(k, v.map((e) => e.toMap()).toList()))));
  }

  void _addCat() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            final n = ctrl.text.trim();
            if (n.isNotEmpty && !cats.containsKey(n)) {
              setState(() => cats[n] = []);
              _save();
            }
            Navigator.pop(context);
          }, child: const Text('Create')),
        ],
      ),
    );
  }

  void _editCat(String oldCat) {
    final ctrl = TextEditingController(text: oldCat);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'New category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            final newCat = ctrl.text.trim();
            if (newCat.isNotEmpty && !cats.containsKey(newCat)) {
              setState(() {
                cats[newCat] = cats.remove(oldCat)!;
                _save();
              });
            }
            Navigator.pop(context);
          }, child: const Text('Rename')),
        ],
      ),
    );
  }

  void _deleteCat(String cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "$cat" and all its timers?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            setState(() {
              cats.remove(cat);
              _save();
            });
            Navigator.pop(context);
          }, child: const Text('Delete')),
        ],
      ),
    );
  }

  void _addOrEditTimer(String cat, [CountdownEvent? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name);
    DateTime? picked = existing?.target;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Timer' : 'Edit Timer'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () async {
                final today = DateTime.now();
                final pick = await showDatePicker(
                  context: context,
                  initialDate: picked ?? today.add(const Duration(days: 1)),
                  firstDate: today,
                  lastDate: DateTime(2100),
                );
                if (pick != null) picked = DateTime(pick.year, pick.month, pick.day);
              },
              child: const Text('Pick Date (12 AM)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            final nm = nameCtrl.text.trim();
            if (nm.isEmpty || picked == null) return;
            setState(() {
              final list = cats[cat]!;
              if (existing != null) {
                existing.name = nm;
                existing.target = picked!;
              } else {
                list.add(CountdownEvent(name: nm, target: picked!));
              }
              list.sort((a, b) => a.target.compareTo(b.target));
              _save();
            });
            Navigator.pop(context);
          }, child: Text(existing == null ? 'Add' : 'Save')),
        ],
      ),
    );
  }

  void _deleteTimer(String cat, CountdownEvent e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Timer'),
        content: Text('Delete "${e.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            setState(() {
              cats[cat]!.remove(e);
              _save();
            });
            Navigator.pop(context);
          }, child: const Text('Delete')),
        ],
      ),
    );
  }

  String _fd(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year.toString().substring(2)}';
  }

  String _fmt(Duration d) {
    if (d.isNegative) return 'Event passed';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    return '${days}d ${hours}h ${minutes}m';
  }

  void _showInfo() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('About Soonishly'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soonishly is a minimal, offline countdown app that helps you track upcoming events cleanly and privately. Built to stay lightweight, ad-free, distraction-free and SQUISHY :3\n\n'
              'How to use it ?\n'
              '> Add a category (eg - Exams, Projects).\n'
              '> Inside a category, tap "+" to add an event with a name and date.\n'
              '> It counts down to 12 AM of that day.\n'
              '> It auto arranges the event by time left.\n'
              '> Long-press an event/category to edit or delete it.\n'
              '> You have to long-press on category-name for pop-up to come [too lazy to fix this].\n',
            ),
            const SizedBox(height: 12),
            const Text(
              'About Me :\n'
              "Am Divyanshu. I make free, open-source apps that don’t spam you with ads or mess with your privacy.\n\n"
              "If you find it useful, please share it or donate :p\n",
            ),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://ko-fi.com/divyanshubruh'), mode: LaunchMode.externalApplication),
              child: const Text('Ko-fi: https://ko-fi.com/divyanshubruh',
                  style: TextStyle(color: Colors.teal, decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://paypal.me/divyanshu6284'), mode: LaunchMode.externalApplication),
              child: const Text('PayPal: https://paypal.me/divyanshu6284',
                  style: TextStyle(color: Colors.teal, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('Countdowns'), actions: [
        IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: _addCat),
        IconButton(icon: const Text(':3', style: TextStyle(fontSize: 20)), onPressed: _showInfo),
      ]),
      body: cats.isEmpty
          ? const Center(child: Text('No categories yet'))
          : ListView(
              children: cats.entries.map((e) {
                final cat = e.key;
                final list = e.value..sort((a, b) => a.target.compareTo(b.target));
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onLongPressStart: (details) async {
                          final pos = details.globalPosition;
                          final choice = await showMenu<String>(
                            context: context,
                            position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
                            items: const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          );
                          if (choice == 'edit') _editCat(cat);
                          if (choice == 'delete') _deleteCat(cat);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(onPressed: () => _addOrEditTimer(cat), icon: const Icon(Icons.add)),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1),
                      ...list.map((ev) {
                        final d = ev.target.difference(DateTime.now());
                        return GestureDetector(
                          onLongPressStart: (details) async {
                            final pos = details.globalPosition;
                            final choice = await showMenu<String>(
                              context: context,
                              position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
                              items: const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            );
                            if (choice == 'edit') _addOrEditTimer(cat, ev);
                            if (choice == 'delete') _deleteTimer(cat, ev);
                          },
                          child: ListTile(
                            title: Text(ev.name),
                            subtitle: Text('${_fmt(d)} • ${_fd(ev.target)}',
                                style: TextStyle(
                                    color: d.isNegative ? Colors.grey : null,
                                    decoration: d.isNegative ? TextDecoration.lineThrough : null)),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
