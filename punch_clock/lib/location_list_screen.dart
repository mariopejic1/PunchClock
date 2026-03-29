import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class LocationListScreen extends StatefulWidget {
  @override
  _LocationListScreenState createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  final _supabase = Supabase.instance.client;

  // Funkcija za brisanje lokacije
  Future<void> _deleteLocation(String id) async {
    try {
      await _supabase.from('locations').delete().eq('id', id);
      setState(() {}); // Osvježi listu nakon brisanja
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lokacija obrisana"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Greška pri brisanju: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Obriši lokaciju?"),
        content: const Text("Jeste li sigurni? Ova akcija se ne može poništiti."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Odustani")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Zatvori prozorčić
              _deleteLocation(id); // POZOVI IZVRŠITELJA IZNAD!
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Obriši", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upravljanje Lokacijama")),
      // Gumb za dodavanje nove lokacije
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-location').then((_) => setState(() {})),
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _supabase.from('locations').select().order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Greška: ${snapshot.error}"));
          }
          final locations = snapshot.data ?? [];

          if (locations.isEmpty) {
            return const Center(child: Text("Nema spremljenih lokacija."));
          }

          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
            final loc = locations[index];
            // Provjera statusa iz baze
            final bool isActive = loc['is_active'] ?? true; 

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              // Ako nije aktivno, malo "izblijedi" cijelu karticu
              child: Opacity(
                opacity: isActive ? 1.0 : 0.6, 
                child: ListTile(
                  leading: Icon(
                    Icons.location_on, 
                    color: isActive ? Colors.blue : Colors.grey, // Siva ikona ako je ugašeno
                  ),
                  title: Text(
                    loc['name'] ?? "Neznano",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      // Precrtaj tekst ako je lokacija neaktivna
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text("${loc['address'] ?? ''}\nRadijus: ${loc['radius_meters']}m"),
                  onTap: () {
                    // Šaljemo podatke lokacije (Map) u formu
                    context.push('/add-location', extra: loc).then((_) => setState(() {})); 
                  },
                  isThreeLine: true,
                  // Ovdje dodajemo Switch i kantu za smeće jedno pored drugog
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- SKLOPKA ZA AKTIVACIJU ---
                      Switch(
                        value: isActive,
                        activeColor: Colors.blue,
                        onChanged: (bool newValue) async {
                          // Odmah šaljemo update u Supabase
                          await _supabase
                              .from('locations')
                              .update({'is_active': newValue})
                              .eq('id', loc['id']);
                          
                          // Osvježi ekran da vidimo promjenu
                          setState(() {}); 
                        },
                      ),
                      // --- KANTA ZA SMEĆE ---
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeleteDialog(loc['id']);
                        },
                      ),
                    ],
                  ),
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