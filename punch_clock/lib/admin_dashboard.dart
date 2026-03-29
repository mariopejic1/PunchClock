import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel"),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              context.go('/'); 
            },
          ),
        ],
      ),
      
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Upravljanje sustavom",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, 
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _adminCard(context, Icons.location_on, "Lokacije", Colors.blue, '/locations'),
                  _adminCard(context, Icons.people, "Zaposlenici", Colors.green, '/'),
                  _adminCard(context, Icons.calendar_month, "Rasporedi", Colors.orange, '/schedules'),
                  _adminCard(context, Icons.assessment, "Izvještaji", Colors.purple, '/'),
                ],
              ),
            ),
            
            Text(
              "Zadnje prijave (Live)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.green),
                    title: Text("Ivan Ivić - Prijava"),
                    subtitle: Text("Lokacija: Ured Vitez • 07:55"),
                  ),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.grey),
                    title: Text("Marko Marić - Odjava"),
                    subtitle: Text("Lokacija: Teren 1 • 15:30"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _adminCard(BuildContext context, IconData icon, String title, Color color, String route) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell( 
        onTap: () {
          context.push(route); 
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}