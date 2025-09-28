import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soalan Lazim (FAQ)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          // Guna ExpansionTile untuk FAQ yang boleh diklik
          ExpansionTile(
            title: Text(
              'Bagaimana cara untuk memohon cuti?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Anda boleh memohon cuti melalui sistem HR Portal kami di pautan ini...'),
              )
            ],
          ),
          ExpansionTile(
            title: Text(
              'Apakah waktu pejabat rasmi?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Waktu pejabat adalah dari jam 9:00 pagi hingga 6:00 petang, Isnin hingga Jumaat.'),
              )
            ],
          ),
          ExpansionTile(
            title: Text(
              'Di mana saya boleh membuat tuntutan perubatan?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Semua tuntutan perubatan perlu dihantar melalui aplikasi "HealthBen". Sila rujuk emel dari HR untuk panduan pemasangan.'),
              )
            ],
          ),
        ],
      ),
    );
  }
}