import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';
import 'headphone_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BluetoothManager(),
      child: MaterialApp(
        title: 'Bluetooth Headphone Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: HeadphoneScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
