import 'package:flutter/material.dart';
import '../colors.dart';
import '../pages/dog_profile/add_dog_page.dart';
import '../pages/dog_profile/dog_profile.dart';
import '../board/board_page.dart';
import '../calendar/calendar.dart';
import '../work_list/work_list.dart';
import '../work/walk_choose.dart';

class MainWidgets {
  static Widget buildProfileSection(String? nickname, String? profilePicture) {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: profilePicture != null && profilePicture.isNotEmpty
              ? NetworkImage(profilePicture)
              : null,
          child: profilePicture == null || profilePicture.isEmpty
              ? const Icon(Icons.face, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 14),
        Text(
          nickname ?? '닉네임을 불러오는 중...',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  static Widget buildDogProfileSection({
    required bool isLoading,
    required List<Map<String, dynamic>> dogProfiles,
    required int currentPhotoIndex,
    required String username,
    required Function() prevDogProfile,
    required Function() nextDogProfile,
    required Function() fetchDogProfiles,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dogProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('등록된 강아지가 없습니다.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  navigatorKey.currentContext!,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditDogProfilePage(username: username),
                  ),
                ).then((_) => fetchDogProfiles());
              },
              child: const Text('강아지 등록하기'),
            ),
          ],
        ),
      );
    }

    final currentDog = dogProfiles[currentPhotoIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: prevDogProfile,
            ),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      navigatorKey.currentContext!,
                      MaterialPageRoute(
                        builder: (context) => DogProfile(username: username),
                      ),
                    ).then((_) => fetchDogProfiles());
                  },
                  child: CircleAvatar(
                    radius: 90,
                    backgroundImage: currentDog['image_url'] != null
                        ? NetworkImage(currentDog['image_url'])
                        : null,
                    child: currentDog['image_url'] == null
                        ? const Icon(Icons.pets, size: 90)
                        : null,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: nextDogProfile,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          currentDog['dog_name'],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  static Widget buildIconButtonRow(
    String username,
    List<Map<String, dynamic>> dogProfiles,
    int currentPhotoIndex,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIconButton(
          "캘린더",
          Icons.calendar_month,
          AppColors.mainYellow,
          () => _handleIconButtonTap(
              "캘린더", username, dogProfiles, currentPhotoIndex),
        ),
        _buildIconButton(
          "게시판",
          Icons.assignment,
          AppColors.mainPink,
          () => _handleIconButtonTap(
              "게시판", username, dogProfiles, currentPhotoIndex),
        ),
        _buildIconButton(
          "리스트",
          Icons.list,
          AppColors.olivegreen,
          () => _handleIconButtonTap(
              "리스트", username, dogProfiles, currentPhotoIndex),
        ),
      ],
    );
  }

  static Widget _buildIconButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.black, size: 32),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14))
        ],
      ),
    );
  }

  static void _handleIconButtonTap(String label, String username,
      List<Map<String, dynamic>> dogProfiles, int currentPhotoIndex) {
    if (dogProfiles.isEmpty && (label == "리스트" || label == "산책")) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(content: Text('등록된 강아지가 없습니다. 먼저 강아지를 등록해주세요.')),
      );
      return;
    }

    final currentDog = dogProfiles[currentPhotoIndex];
    final dogId = currentDog['id'];
    final dogName = currentDog['dog_name'];

    switch (label) {
      case "캘린더":
        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (context) => CalendarPage(username: username),
          ),
        );
        break;
      case "게시판":
        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (context) => BoardPage(username: username),
          ),
        );
        break;
      case "리스트":
        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (context) =>
                WorkList(username: username, dogId: dogId, dogName: dogName),
          ),
        );
        break;
    }
  }
}

// Global NavigatorKey for accessing context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
