import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dangq/work/walk_choose.dart'; // Walk_choose import 추가

//산책 시작 전 반려견 프로필 선택 페이지

class Dog_list extends StatefulWidget {
  final String username;

  const Dog_list({super.key, required this.username});
  @override
  State<Dog_list> createState() => dog_list();
}

class dog_list extends State<Dog_list> {
  // 임시 프로필 데이터 *****지우고 프로필 API 넣기 없애면 오류나서 나둠
  final List<String> profiles = ['1'];

  String? selectedProfile;

  @override
  void initState() {
    super.initState();
    selectedProfile = profiles[0];
  }

  //프로필 갯수만큼 프로필 원형 만들어주는 함수
  Widget buildProfileCircle(String profileName) {
    bool isSelected = selectedProfile == profileName;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedProfile = isSelected ? null : profileName;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            margin: EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
              //누르면 초록색 태두리 생성
              border: isSelected
                  ? Border.all(
                      color: AppColors.lightgreen,
                      width: 3,
                    )
                  : null,
            ),
          ),
          SizedBox(height: 5),
          Text(
            profileName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
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
            // 프로필 목록데로 프로필 원형 생성
            GridView.builder(
              padding: EdgeInsets.fromLTRB(20, 80, 20, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                return buildProfileCircle(profiles[index]);
              },
            ),
            // 기존 하단 버튼
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            Walk_choose(username: widget.username),
                      ),
                    );
                  },
                  child: Text(
                    '선택하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightgreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
