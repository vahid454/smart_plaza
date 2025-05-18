import 'package:flutter/material.dart';
import 'login_screen.dart'; // Next step

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Smart Plaza", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}