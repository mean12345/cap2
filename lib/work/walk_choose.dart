import 'dart:convert';
import 'package:dangq/colors.dart';
import 'package:dangq/work/work_self/work.dart';
import 'package:dangq/work/dog_list.dart'; // DogListPage import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

class WalkChoose extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;

  const WalkChoose({
    super.key,
    required this.username,
    required this.dogId,
    required this.dogName,
  });

  @override
  State<WalkChoose> createState() => WalkChooseState();
}

class WalkChooseState extends State<WalkChoose> {
  List<Map<String, dynamic>> dogProfiles = [];
  bool _isLoading = false;

  // 현재 선택된 강아지 정보
  late int _selectedDogId;
  late String _selectedDogName;
  String _selectedDogImageUrl = '';

  final String baseUrl = dotenv.env['BASE_URL']!;

  @override
  void initState() {
    super.initState();
    _selectedDogId = widget.dogId;
    _selectedDogName = widget.dogName;
    _fetchDogProfiles();
  }

  void _updateSelectedDog(int dogId, String dogName, String imageUrl) {
    setState(() {
      _selectedDogId = dogId;
      _selectedDogName = dogName;
      _selectedDogImageUrl = imageUrl;
    });
  }

  Future<void> _fetchDogProfiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = '$baseUrl/dogs/get_dogs?username=${widget.username}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 404) {
        setState(() {
          dogProfiles = [];
          _isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);
        setState(() {
          dogProfiles = jsonResponse
              .map((dog) => {
                    'dog_name': dog['name'],
                    'image_url': dog['imageUrl'],
                    'id': dog['id'],
                  })
              .toList();

          final selectedDog = dogProfiles.firstWhere(
            (dog) => dog['id'] == _selectedDogId,
            orElse: () => dogProfiles.isNotEmpty
                ? dogProfiles[0]
                : {
                    'dog_name': _selectedDogName,
                    'image_url': '',
                    'id': _selectedDogId,
                  },
          );

          _selectedDogId = selectedDog['id'];
          _selectedDogName = selectedDog['dog_name'];
          _selectedDogImageUrl = selectedDog['image_url'] ?? '';

          _isLoading = false;
        });
      } else {
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: MediaQuery.of(context).size.height * 0.05,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 35),
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
              options: const NaverMapViewOptions(
                locationButtonEnable: false,
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(37.5666102, 126.9783881),
                  zoom: 15,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: const BoxDecoration(color: Colors.white),
                child: Padding(
                  padding: const EdgeInsets.only(top: 35),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOptionButton('경로 추천 받기'),
                      _buildOptionButton('산책하기'),
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
                      builder: (context) => DogListPage(
                        username: widget.username,
                        onDogSelected: (int id, String name, String imageUrl) {
                          _updateSelectedDog(id, name, imageUrl);
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : _selectedDogImageUrl.isEmpty
                            ? const Icon(Icons.pets,
                                size: 50, color: Colors.grey)
                            : ClipOval(
                                child: Image.network(
                                  _selectedDogImageUrl,
                                  width: 85,
                                  height: 85,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.pets,
                                        size: 50, color: Colors.grey);
                                  },
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
                    _selectedDogName,
                    style: const TextStyle(
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

  Widget _buildOptionButton(String text) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Work(
              username: widget.username,
              dogId: _selectedDogId,
              dogName: _selectedDogName,
            ),
          ),
        );
      },
      child: Container(
        width: 300,
        height: 45,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: AppColors.lightgreen,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
