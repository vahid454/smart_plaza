import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ReportsScreen extends StatelessWidget {
  final Function(String, Map<String, dynamic>)? onItemSelect;

  ReportsScreen({this.onItemSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("All Items")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inventory').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return ListTile(
                title: Text(doc['name']),
                subtitle: Text(doc['imei']),
                onTap: () {
                  if (onItemSelect != null) {
                    onItemSelect!(doc.id, doc.data() as Map<String, dynamic>);
                  } else {
                    // View mode
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}