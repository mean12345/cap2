import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:dangq/pages/dog_profile/add_dog_profile.dart';
import 'package:dangq/pages/dog_profile/fix_dog_profile.dart'; // import 추가

class DogProfile extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;

  const DogProfile({
    super.key,
    required this.username,
    required this.dogId,
    required this.dogName,
  });

  @override
  State<DogProfile> createState() => _DogProfileState();
}

class _DogProfileState extends State<DogProfile> {
  List<String> profiles = ['1', '2', '3', '4'];

  Widget buildProfileCircle(String profileName) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const Fix_dog()), ////프로필을 누르면 프로필 수정 페이지로 이동
        );
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

  Widget buildAddProfileButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const Add_dog()), //+을 누르면 프로필 생성성 페이지로 이동
        );
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
              border: Border.all(
                color: const Color.fromARGB(255, 153, 153, 153),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 70,
              color: const Color.fromARGB(255, 153, 153, 153),
            ),
          ),
          SizedBox(height: 5),
          Text(
            '반려견 추가',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
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
        backgroundColor: AppColors.background,
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
          //systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: Stack(
          children: [
            //프로필 원형 생성 정렬
            GridView.builder(
              padding: EdgeInsets.fromLTRB(20, 80, 20, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, //1줄에 프로필 2개씩
                mainAxisSpacing: 3, //세로간격
                crossAxisSpacing: 10, //가로간격
                childAspectRatio: 0.9, //가로세로 비율
              ),
              //+ 추가 버튼
              itemCount: profiles.length + 1,
              itemBuilder: (context, index) {
                if (index == profiles.length) {
                  return buildAddProfileButton();
                }
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
                    Navigator.pop(context);
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
