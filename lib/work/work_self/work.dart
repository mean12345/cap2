import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dangq/work/work_self/draggable_dst/draggable_dst.dart';

class Work extends StatefulWidget {
  final String username;

  const Work({super.key, required this.username});

  @override
  State<Work> createState() => _WorkState();
}

class _WorkState extends State<Work> {
  double _checkPlaceTop = 0.07; // 초기값 설정
  String? profileImage; // 프로필 이미지 URL

  void _updateCheckPlaceTop(double newTop) {
    setState(() {
      _checkPlaceTop = newTop;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        extendBodyBehindAppBar: true, // 앱바 뒤로 컨텐츠가 확장되도록 설정
        appBar: AppBar(
          toolbarHeight: MediaQuery.of(context).size.height * 0.05,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 35, // 아이콘 자체 크기
            ),
            onPressed: () {
              Navigator.pop(context); // 이전 페이지로 이동
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: Stack(
          children: [
            WorkDST(username: widget.username),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.05, // AppBar 아래로 조정
              right: 16,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),

                // 프로필 이미지 조건문 넣을 곳 **********
                child: profileImage != null
                    ? ClipOval(
                        child: Image.network(
                          profileImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    //이미지 없을 경우 아이콘 나타냄
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
