import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // dotenv 쓰려면

import 'package:dangq/work/work_self/draggable_dst/draggable_dst.dart';

class Work extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;

  const Work({
    super.key,
    required this.username,
    required this.dogId,
    required this.dogName,
  });

  @override
  State<Work> createState() => _WorkState();
}

class _WorkState extends State<Work> {
  double _checkPlaceTop = 0.07;
  String? profileImage;
  bool _isLoading = false;

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
          profileImage = null;
          _isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);

        // dogProfiles 중 dogId와 일치하는 것 찾기
        final dog = jsonResponse.firstWhere(
          (dog) => dog['id'] == widget.dogId,
          orElse: () => null,
        );

        setState(() {
          profileImage = dog != null ? dog['imageUrl'] as String? : null;
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

  void _updateCheckPlaceTop(double newTop) {
    setState(() {
      _checkPlaceTop = newTop;
    });
  }

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
            WorkDST(username: widget.username, dogId: widget.dogId),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.05,
              right: 16,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : profileImage != null
                        ? ClipOval(
                            child: Image.network(
                              profileImage!,
                              fit: BoxFit.cover,
                            ),
                          )
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
