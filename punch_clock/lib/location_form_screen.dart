import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class LocationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialLocation;

  const LocationFormScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  _LocationFormScreenState createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '20'); 
  bool _isLoading = false;

  bool get _isEditing => widget.initialLocation != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final loc = widget.initialLocation!;
      _nameController.text = loc['name'] ?? '';
      _addressController.text = loc['address'] ?? '';
      _latController.text = loc['latitude']?.toString() ?? '';
      _lngController.text = loc['longitude']?.toString() ?? '';
      _radiusController.text = loc['radius_meters']?.toString() ?? '20';
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Greška: Korisnik nije prijavljen!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    print("Korisnik meta: ${user?.appMetadata}");
    
    try {
      final locationData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': double.parse(_latController.text),
        'longitude': double.parse(_lngController.text),
        'radius_meters': int.tryParse(_radiusController.text) ?? 20,
      };

      if (_isEditing) {
        await supabase
            .from('locations')
            .update(locationData)
            .eq('id', widget.initialLocation!['id']);
      } else {
        locationData['created_by'] = user.id; 
        await supabase.from('locations').insert(locationData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? "Lokacija ažurirana!" : "Lokacija spremljena!"),
          backgroundColor: Colors.green
        ),
      );
      context.pop(); 

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Greška: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? "Uredi Lokaciju" : "Nova Lokacija")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Naziv (npr. Ured Osijek)"),
                validator: (v) => v!.isEmpty ? "Obavezno polje" : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: "Adresa"),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: "Lat"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? "Obavezno" : null,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(labelText: "Lng"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? "Obavezno" : null,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(labelText: "Radijus (metara)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 30),
              _isLoading 
                ? const CircularProgressIndicator() 
                : ElevatedButton(
                    onPressed: _saveLocation, 
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: Text(_isEditing ? "AŽURIRAJ LOKACIJU" : "SPREMI LOKACIJU"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}