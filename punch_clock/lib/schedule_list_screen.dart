import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ScheduleListScreen extends StatefulWidget {
  @override
  _ScheduleListScreenState createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  final _supabase = Supabase.instance.client;
  String? _filterUserId;
  String? _filterLocationId;

  final Map<int, String> _dayNames = {
    1: 'Pon', 2: 'Uto', 3: 'Sri', 4: 'Čet', 5: 'Pet', 6: 'Sub', 7: 'Ned'
  };

  Future<List<Map<String, dynamic>>> _fetchSchedules() async {
    var query = _supabase.from('schedules').select('''
      *,
      users:user_id(name), 
      locations:location_id(name)
    ''');

    if (_filterUserId != null) query = query.eq('user_id', _filterUserId!);
    if (_filterLocationId != null) query = query.eq('location_id', _filterLocationId!);

    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  void _showFilterDialog() async {
    final users = await _supabase.from('users').select('id, name').order('name');
    final locs = await _supabase.from('locations').select('id, name').order('name');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Filtriraj po imenu ili lokaciji"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _filterUserId,
                    hint: const Text("Svi zaposlenici"),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Svi zaposlenici")),
                      ...users.map((u) => DropdownMenuItem(
                        value: u['id'].toString(), 
                        child: Text(u['name'] ?? "Bez imena") 
                      )),
                    ],
                    onChanged: (val) => setDialogState(() => _filterUserId = val),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _filterLocationId,
                    hint: const Text("Sve lokacije"),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Sve lokacije")),
                      ...locs.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text(l['name']))),
                    ],
                    onChanged: (val) => setDialogState(() => _filterLocationId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterUserId = null;
                      _filterLocationId = null;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("Očisti"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(ctx);
                  },
                  child: const Text("Primijeni"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Svi Rasporedi"),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list, 
              color: (_filterUserId != null || _filterLocationId != null) ? Colors.orange : null
            ),
            onPressed: _showFilterDialog,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-schedule').then((_) => setState(() {})),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSchedules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Greška: ${snapshot.error}"));
          
          final schedules = snapshot.data ?? [];
          if (schedules.isEmpty) return const Center(child: Text("Nema pronađenih rasporeda."));

          return ListView.builder(
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final s = schedules[index];
              final userName = s['users']?['name'] ?? 'Nepoznat radnik';
              final locName = s['locations']?['name'] ?? 'Nepoznata lokacija';
              
              final List<dynamic> daysRaw = s['days_of_week'] ?? [];
              final String daysFormatted = daysRaw.map((d) => _dayNames[d] ?? d).join(', ');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                child: ListTile(
                  onTap: () => context.push('/add-schedule', extra: s).then((_) => setState(() {})),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    child: Icon(Icons.person, color: Colors.white, size: 20), 
                  ),
                  title: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📍 $locName", style: const TextStyle(color: Colors.blueGrey)),
                        Text("⏰ ${s['work_start'].substring(0, 5)} - ${s['work_end'].substring(0, 5)}"),
                        Text("📅 $daysFormatted", style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Brisanje"),
                          content: const Text("Želite li obrisati ovaj raspored?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Odustani")),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Obriši")),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _supabase.from('schedules').delete().eq('id', s['id']);
                        setState(() {});
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}