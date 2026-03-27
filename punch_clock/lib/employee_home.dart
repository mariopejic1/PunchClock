import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmployeeHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Moj Raspored"),
        backgroundColor: Colors.blueAccent,
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Današnji zadatak:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.location_on, color: Colors.red),
                title: Text("Lokacija: Ured Vitez"),
                subtitle: Text("Radno vrijeme: 08:00 - 16:00"),
              ),
            ),
            Spacer(), 
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      print("Check-in pritisnut");
                    },
                    child: Text("PRIJAVI DOLAZAK", style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      print("Check-out pritisnut");
                    },
                    child: Text("ODJAVI ODLAZAK", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}