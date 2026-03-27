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
                  _adminCard(Icons.location_on, "Lokacije", Colors.blue),
                  _adminCard(Icons.people, "Zaposlenici", Colors.green),
                  _adminCard(Icons.calendar_month, "Rasporedi", Colors.orange),
                  _adminCard(Icons.assessment, "Izvještaji", Colors.purple),
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

  Widget _adminCard(IconData icon, String title, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell( 
        onTap: () {
          print("Kliknuto na $title");
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}