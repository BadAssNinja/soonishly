import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TimeHomePage extends StatefulWidget {
  const TimeHomePage({super.key});

  @override
  State<TimeHomePage> createState() => _TimeHomePageState();
}

class _TimeHomePageState extends State<TimeHomePage> {
  final TextEditingController _eventController = TextEditingController();
  DateTime? _targetDate;
  Duration _remaining = Duration.zero;
  Timer? _timer;
  bool _showColon = true;

  @override
  void initState() {
    super.initState();
    _loadLastEvent();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_targetDate != null) {
          _remaining = _targetDate!.difference(DateTime.now());
          if (_remaining.isNegative) _remaining = Duration.zero;
          _showColon = !_showColon;
        }
      });
    });
  }

  Future<void> _saveEvent(String name, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eventName', name);
    await prefs.setString('eventDate', date.toIso8601String());
  }

  Future<void> _loadLastEvent() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('eventName');
    final dateStr = prefs.getString('eventDate');
    if (name != null && dateStr != null) {
      _eventController.text = name;
      _targetDate = DateTime.tryParse(dateStr);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 0, minute: 0),
      );

      if (time != null) {
        final target = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        setState(() {
          _targetDate = target;
          _saveEvent(_eventController.text, target);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    final colon = _showColon ? ':' : ' ';
    return '$days days $hours hrs $minutes min$colon$seconds sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Countdown: Time Until')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _eventController,
              decoration: const InputDecoration(labelText: 'Event Name'),
              onChanged: (_) => _saveEvent(_eventController.text, _targetDate ?? DateTime.now()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickDate,
              child: const Text('Pick Target Date'),
            ),
            const SizedBox(height: 24),
            if (_targetDate != null)
              Column(
                children: [
                  Text(
                    'Countdown to ${_eventController.text.trim()}:',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDuration(_remaining),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
