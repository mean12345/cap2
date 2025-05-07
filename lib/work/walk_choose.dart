import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dangq/work/work_self/work.dart';
import 'package:dangq/work/dog_list.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class Walk_choose extends StatefulWidget {
  final String username;

  const Walk_choose({super.key, required this.username});
  @override
  State<Walk_choose> createState() => walk_choose();
}

class walk_choose extends State<Walk_choose> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: MediaQuery.of(context).size.height * 0.05,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 35,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: Stack(
          children: [
            NaverMap(
              onMapReady: (controller) {
                controller
                    .setLocationTrackingMode(NLocationTrackingMode.follow);
              },
              options: NaverMapViewOptions(
                locationButtonEnable: false,
                initialCameraPosition: NCameraPosition(
                  target: const NLatLng(37.5666102, 126.9783881),
                  zoom: 15,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: 35),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Work(username: widget.username),
                            ),
                          );
                        },
                        child: Container(
                          width: 300,
                          height: 45,
                          margin: EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: AppColors.lightgreen,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Center(
                            child: Text(
                              '경로 추천 받기',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Work(username: widget.username),
                            ),
                          );
                        },
                        child: Container(
                          width: 300,
                          height: 45,
                          margin: EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: AppColors.lightgreen,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Center(
                            child: Text(
                              '산책하기',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.19,
              left: 15,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Dog_list(username: widget.username),
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.21,
              left: 125,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
