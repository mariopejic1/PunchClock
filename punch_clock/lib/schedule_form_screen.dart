import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ScheduleFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialSchedule;

  const ScheduleFormScreen({Key? key, this.initialSchedule}) : super(key: key);

  @override
  _ScheduleFormScreenState createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String? _selectedUserId;
  String? _selectedLocationId;
  
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  DateTime _validFrom = DateTime.now();
  DateTime? _validTo;

  final _toleranceController = TextEditingController(text: '15');
  final _breakController = TextEditingController(text: '30');

  List<int> _selectedDays = [];
  final List<Map<String, dynamic>> _weekDays = [
    {'id': 1, 'name': 'Pon'}, {'id': 2, 'name': 'Uto'}, {'id': 3, 'name': 'Sri'},
    {'id': 4, 'name': 'Čet'}, {'id': 5, 'name': 'Pet'}, {'id': 6, 'name': 'Sub'}, {'id': 7, 'name': 'Ned'},
  ];

  bool get _isEditing => widget.initialSchedule != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.initialSchedule!;
      _selectedUserId = s['user_id'];
      _selectedLocationId = s['location_id'];
      _selectedDays = List<int>.from(s['days_of_week']);
      _toleranceController.text = s['tolerance_mins'].toString();
      _breakController.text = s['break_duration_mins'].toString();
      _validFrom = DateTime.parse(s['valid_from']);
      if (s['valid_to'] != null) _validTo = DateTime.parse(s['valid_to']);

      final startParts = s['work_start'].split(':');
      _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      final endParts = s['work_end'].split(':');
      _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate() || 
        _selectedUserId == null || 
        _selectedLocationId == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Popunite sva polja, uključujući radno vrijeme!"))
      );
      return;
    }

    try {
      final data = {
        'user_id': _selectedUserId,
        'location_id': _selectedLocationId,
        'work_start': "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00",
        'work_end': "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00",
        'days_of_week': _selectedDays,
        'tolerance_mins': int.parse(_toleranceController.text),
        'break_duration_mins': int.parse(_breakController.text),
        'valid_from': _validFrom.toIso8601String().split('T')[0],
        'valid_to': _validTo?.toIso8601String().split('T')[0],
      };

      if (_isEditing) {
        await _supabase.from('schedules').update(data).eq('id', widget.initialSchedule!['id']);
      } else {
        data['created_by'] = _supabase.auth.currentUser?.id;
        await _supabase.from('schedules').insert(data);
      }

      if (mounted) context.pop();
    } catch (e) {
      print("Greška pri spremanju rasporeda: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? "Uredi Raspored" : "Novi Raspored")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Zaposlenik:", style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _supabase.from('users').select('id, name').order('name'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  final users = snapshot.data ?? [];
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    items: users.map((u) => DropdownMenuItem(
                      value: u['id'].toString(), 
                      child: Text(u['name'] ?? "Nema imena")
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedUserId = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), 
                      hintText: "Odaberi radnika po imenu"
                    ),
                    validator: (val) => val == null ? "Obavezno polje" : null,
                  );
                },
              ),
              const SizedBox(height: 20),

              const Text("Lokacija:", style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _supabase.from('locations').select('id, name').eq('is_active', true).order('name'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator());
                  }
                  final locs = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _selectedLocationId,
                    items: locs.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text(l['name']))).toList(),
                    onChanged: (val) => setState(() => _selectedLocationId = val),
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Odaberi ured"),
                    validator: (val) => val == null ? "Lokacija je obavezna" : null,
                  );
                },
              ),
              const SizedBox(height: 20),

              const Text("Radni dani:", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day['id']);
                  return FilterChip(
                    label: Text(day['name']),
                    selected: isSelected,
                    selectedColor: Colors.orangeAccent.withOpacity(0.5),
                    onSelected: (selected) {
                      setState(() {
                        selected ? _selectedDays.add(day['id']) : _selectedDays.remove(day['id']);
                        _selectedDays.sort();
                      });
                    },
                  );
                }).toList(),
              ),

              const Divider(height: 40),

              const Text("Radno vrijeme:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                      title: const Padding(padding: EdgeInsets.only(left: 8.0), child: Text("Početak")),
                      subtitle: Padding(padding: EdgeInsets.only(left: 8.0), child: Text(_startTime?.format(context) ?? "Odaberi...")),
                      trailing: const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.access_time)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                        if (t != null) setState(() => _startTime = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                      title: const Padding(padding: EdgeInsets.only(left: 8.0), child: Text("Kraj")),
                      subtitle: Padding(padding: EdgeInsets.only(left: 8.0), child: Text(_endTime?.format(context) ?? "Odaberi...")),
                      trailing: const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.access_time)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay.now());
                        if (t != null) setState(() => _endTime = t);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              
              TextFormField(
                controller: _toleranceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Tolerancija (min)", border: OutlineInputBorder()),
                validator: (val) => (val == null || val.isEmpty) ? "Unesite minute" : null,
              ),
              
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _breakController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Trajanje pauze (min)", border: OutlineInputBorder()),
                validator: (val) => (val == null || val.isEmpty) ? "Unesite minute" : null,
              ),

              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: _saveSchedule,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isEditing ? "AŽURIRAJ RASPORSRED" : "SPREMI RASPORSRED", style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}