import 'package:flutter/material.dart';
import 'package:dangq/work/draggable_dst/draggable_dst.dart';

class Work extends StatefulWidget {
  final String username;

  const Work({super.key, required this.username});

  @override
  State<Work> createState() => _WorkState();
}

class _WorkState extends State<Work> {
  double _checkPlaceTop = 0.07; // 초기값 설정

  void _updateCheckPlaceTop(double newTop) {
    setState(() {
      _checkPlaceTop = newTop;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.of(context).size.height * 0.05,
          leading: Image.asset('assets/images/back.png'),
          backgroundColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            WorkDST(username: widget.username),
          ],
        ),
      ),
    );
  }
}
