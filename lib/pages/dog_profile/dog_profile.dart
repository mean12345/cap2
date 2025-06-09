import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_dog_profile.dart';
import 'package:dangq/pages/main/main_page.dart';

class DogProfile extends StatefulWidget {
  final String username;

  const DogProfile({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  State<DogProfile> createState() => _DogProfileState();
}

class _DogProfileState extends State<DogProfile> {
  List<Map<String, dynamic>> dogProfiles = [];
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
          dogProfiles = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        toolbarHeight: MediaQuery.of(context).size.height * 0.07,
        title: Text(
          '반려견 프로필',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: dogProfiles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == dogProfiles.length) {
                      return buildAddProfileButton();
                    }
                    return _buildDogProfileCircle(dogProfiles[index]);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildDogProfileCircle(Map<String, dynamic> dog) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditDogProfilePage(
              username: widget.username,
              dogProfile: {
                'id': dog['id'],
                'name': dog['dog_name'],
                'imageUrl': dog['image_url'],
              },
            ),
          ),
        ).then((result) {
          if (result == true) {
            _fetchDogProfiles();
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: dog['image_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(dog['image_url']),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: dog['image_url'] == null ? Colors.grey[300] : null,
            ),
            child: dog['image_url'] == null
                ? Icon(
                    Icons.pets,
                    size: 50,
                    color: Colors.grey[600],
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            dog['dog_name'] ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
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
              builder: (context) =>
                  EditDogProfilePage(username: widget.username)),
        ).then((_) => _fetchDogProfiles());
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
                color: const Color.fromARGB(255, 181, 181, 181),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 70,
              color: const Color.fromARGB(255, 181, 181, 181),
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
}
