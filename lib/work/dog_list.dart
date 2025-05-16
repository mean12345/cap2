import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/work/walk_choose.dart';

class DogListPage extends StatefulWidget {
  final String username;

  const DogListPage({
    Key? key,
    required this.username,
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
      print('요청 URL: $url'); // 요청 URL 확인 로그

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
            width: 100,
            height: 100,
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
      appBar: AppBar(
        title: Text('반려견 선택'),
        backgroundColor: Colors.white,
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: dogProfiles.isNotEmpty
              ? () {
                  final selectedDog = dogProfiles[_currentPhotoIndex];
                  final dogId = selectedDog['id'];
                  final dogName = selectedDog['dog_name'];

                  print('선택한 반려견: $dogName (ID: $dogId)');

                  // WalkChoose 페이지로 이동하면서 username과 dogId 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkChoose(
                        username: widget.username,
                        dogId: dogId,
                        dogName: dogName,
                      ),
                    ),
                  );
                }
              : null,
          child: Text('선택하기'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[300],
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}
