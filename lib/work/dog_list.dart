import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/colors.dart';

class DogListPage extends StatefulWidget {
  final String username;
  final void Function(int, String, String) onDogSelected;

  const DogListPage({
    Key? key,
    required this.username,
    required this.onDogSelected,
  }) : super(key: key);

  @override
  State<DogListPage> createState() => _DogListPageState();
}

class _DogListPageState extends State<DogListPage> {
  List<Map<String, dynamic>> dogProfiles = [];
  bool _isLoading = false;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchDogProfiles();
  }

  Future<void> _fetchDogProfiles() async {
    setState(() {
      _isLoading = true;
    });
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final url = '$baseUrl/dogs/get_dogs?username=${widget.username}';
      print('요청 URL: $url');

      final response = await http.get(Uri.parse(url));
      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      if (response.statusCode == 404) {
        setState(() {
          dogProfiles = [];
          _currentPhotoIndex = 0;
          _isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);

        setState(() {
          dogProfiles = jsonResponse
              .map<Map<String, dynamic>>((dog) => {
                    'dog_name': dog['name'],
                    'image_url': dog['imageUrl'],
                    'id': dog['id'],
                  })
              .toList();

          if (dogProfiles.isNotEmpty &&
              _currentPhotoIndex >= dogProfiles.length) {
            _currentPhotoIndex = dogProfiles.length - 1;
          }

          _isLoading = false;
        });
      } else {
        print('실패: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load dog profiles');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('예외 발생: $e');
      rethrow;
    }
  }

  Widget _buildDogProfileCircle(Map<String, dynamic> dog) {
    final isSelected = dogProfiles.indexOf(dog) == _currentPhotoIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentPhotoIndex = dogProfiles.indexOf(dog);
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120, // 100에서 120으로 증가
            height: 120, // 100에서 120으로 증가
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  isSelected ? Border.all(color: Colors.green, width: 3) : null,
              image: dog['image_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(dog['image_url']),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: dog['image_url'] == null ? Colors.grey[300] : null,
            ),
          ),
          Text(
            dog['dog_name'] ?? '',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('반려견 선택'),
        backgroundColor: Colors.transparent, // 배경색 투명으로 변경
        foregroundColor: Colors.black,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : dogProfiles.isEmpty
              ? Center(child: Text('등록된 반려견이 없습니다.'))
              : GridView.builder(
                  padding: EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: dogProfiles.length,
                  itemBuilder: (context, index) {
                    return _buildDogProfileCircle(dogProfiles[index]);
                  },
                ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, 30),
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: dogProfiles.isNotEmpty
              ? () {
                  final selectedDog = dogProfiles[_currentPhotoIndex];
                  final dogId = selectedDog['id'];
                  final dogName = selectedDog['dog_name'];

                  print('선택한 반려견: $dogName (ID: $dogId)');

                  widget.onDogSelected(
                    dogId,
                    dogName,
                    selectedDog['image_url'],
                  );

                  Navigator.pop(context); // 콜백 호출 후 닫기
                }
              : null,
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
    );
  }
}
