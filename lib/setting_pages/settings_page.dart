import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/login/login.dart';
import 'package:dangq/setting_pages/edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  final String username;

  const SettingsPage({super.key, required this.username});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? userRole;
  List<String> relatedUsers = [];
  List<String> otherMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileInfo(widget.username);

    _loadRelationships();
  }

  final String baseUrl = dotenv.get('BASE_URL');
  Future<Map<String, String>> _fetchProfileInfo(String username) async {
    final String baseUrl = dotenv.get('BASE_URL');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=$username'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'nickname': jsonResponse['nickname'] ?? '닉네임을 불러오는 중...',
          'profile_picture': jsonResponse['profile_picture'] ?? '',
        };
      } else {
        throw Exception('프로필 정보 불러오기 실패');
      }
    } catch (e) {
      throw Exception('프로필 정보 불러오기 실패: $e');
    }
  }

  Future<void> _loadRelationships() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/${widget.username}/relationships'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userRole = data['role'];
          relatedUsers = List<String>.from(data['relatedUsers']);
          otherMembers = List<String>.from(data['otherMembers']);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관계 정보를 불러오는데 실패했습니다.')),
      );
    }
  }

  // 로그아웃 함수
  Future<void> _handleLogout(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '로그아웃',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text(
                  '정말 로그아웃 하시겠습니까?',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '로그아웃',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // 계정 삭제 함수
  Future<void> _handleDeleteAccount(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '계정 삭제',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text(
                  '정말 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '삭제',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/users/${widget.username}'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        if (response.statusCode == 200) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Login()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('계정 삭제에 실패했습니다.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 연결에 실패했습니다.')),
        );
      }
    }
  }

  // 초대 코드 생성
  Future<void> _generateConnectionCode(BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/connection-codes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': widget.username}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final code = data['code'];

        // 초대 코드 다이얼로그 표시
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '초대 코드',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 25),
                    Text(
                      '코드: $code',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '10분 동안 유효합니다.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          child: Text(
                            '취소',
                            style: TextStyle(color: Colors.grey),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        SizedBox(width: 30),
                        TextButton(
                          child: Text(
                            '복사',
                            style: TextStyle(color: Color(0xFF4DA374)),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('초대 코드가 복사되었습니다.')),
                            );
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 연결에 실패했습니다.')),
      );
    }
  }

  // 초대 코드 입력
  Future<void> _enterConnectionCode(BuildContext context) async {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '초대 코드 입력',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: '초대 코드',
                    labelStyle: TextStyle(color: Color(0xFF4DA374)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: Color(0xFF4DA374)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: Color(0xFF4DA374)),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '확인',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () async {
                        final code = codeController.text.trim();
                        if (code.isEmpty) return;

                        try {
                          final response = await http.post(
                            Uri.parse('$baseUrl/connect'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'username': widget.username,
                              'connectionCode': code,
                            }),
                          );

                          if (response.statusCode == 200) {
                            Navigator.pop(context);
                            _loadRelationships();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('연결이 성공적으로 완료되었습니다.')),
                            );
                          } else {
                            final error = jsonDecode(response.body);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      error['message'] ?? '유효하지 않은 초대 코드입니다.')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('서버 연결에 실패했습니다.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 멤버 삭제 함수 (리더용)
  Future<void> _removeMember(String memberUsername) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '멤버 삭제',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text(
                  '$memberUsername 멤버를 정말 삭제하시겠습니까?',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '삭제',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/relationships/member/$memberUsername'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': widget.username}),
        );

        if (response.statusCode == 200) {
          await _loadRelationships();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('멤버가 삭제되었습니다.')),
          );
        } else {
          final error = jsonDecode(response.body);
          throw Exception(error['message']);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().contains('Exception:')
                  ? e.toString().split('Exception: ')[1]
                  : '멤버 삭제에 실패했습니다.')),
        );
      }
    }
  }

  // 탈퇴 함수 (멤버용)
  Future<void> _leaveGroup() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '그룹 탈퇴',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text(
                  '정말 탈퇴하시겠습니까?\n탈퇴 후에는 되돌릴 수 없습니다.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '탈퇴',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/relationships/leave'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': widget.username}),
        );

        if (response.statusCode == 200) {
          _loadRelationships();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('탈퇴가 완료되었습니다.')),
          );
        } else {
          throw Exception('Failed to leave group');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('탈퇴에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent, // 배경색 투명으로 설정
        elevation: 0, // 그림자 제거
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // 사용자 정보
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '계정 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 프로필 이미지
                      FutureBuilder<Map<String, String>>(
                        future: _fetchProfileInfo(widget.username),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircleAvatar(
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasError || !snapshot.hasData) {
                            return const CircleAvatar(
                              backgroundColor: Color(0xFFE0E0E0),
                              radius: 50,
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF9E9E9E),
                                size: 65,
                              ),
                            );
                          } else {
                            final profileInfo = snapshot.data!;
                            return profileInfo['profile_picture'] != null &&
                                    profileInfo['profile_picture']!.isNotEmpty
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(
                                        profileInfo['profile_picture']!),
                                    radius: 40,
                                  )
                                : const CircleAvatar(
                                    backgroundColor: Color(0xFFE0E0E0),
                                    radius: 40,
                                    child: Icon(
                                      Icons.person,
                                      color: Color(0xFF9E9E9E),
                                      size: 55,
                                    ),
                                  );
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10), // 추가된 부분
                            // 사용자 정보
                            FutureBuilder<Map<String, String>>(
                              future: _fetchProfileInfo(widget.username),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text('닉네임을 불러오는 중...');
                                } else if (snapshot.hasError) {
                                  return const Text('닉네임을 불러오는 데 실패했습니다.');
                                } else if (snapshot.hasData) {
                                  final profileInfo = snapshot.data!;
                                  return Text(
                                    'ID : ${widget.username}\n닉네임 : ${profileInfo['nickname'] ?? '닉네임을 불러오는 중...'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                } else {
                                  return const Text('닉네임을 불러오는 중...');
                                }
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(userRole == 'leader' ? '리더' : '멤버'),
                            const SizedBox(height: 8),
                            // 프로필 수정 버튼
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.lightgreen,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditProfilePage(
                                          username: widget.username),
                                    ),
                                  );
                                  if (result == true) {
                                    setState(() {});
                                  }
                                },
                                child: const Text('프로필 수정'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 관계 정보
          if (userRole != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '관계 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (userRole == 'leader')
                          ListTile(
                            leading: const Icon(
                              Icons.person,
                              size: 35,
                            ),
                            title: const Text('멤버 목록'),
                            subtitle: relatedUsers.isEmpty
                                ? const Text('멤버가 없습니다')
                                : Text(relatedUsers.join(', ')),
                          )
                        else
                          ListTile(
                            leading: const Icon(
                              Icons.person,
                              size: 35,
                            ),
                            title: const Text('리더'),
                            subtitle: relatedUsers.isEmpty
                                ? const Text('리더가 없습니다')
                                : Text(relatedUsers.first),
                          ),
                        if (otherMembers.isNotEmpty)
                          ListTile(
                            leading: const Icon(
                              Icons.person,
                              size: 35,
                            ),
                            title: const Text('다른 멤버'),
                            subtitle: Text(otherMembers.join(', ')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          // 초대 코드 관련 기능
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('초대 코드 생성'),
            onTap: () => _generateConnectionCode(context),
            enabled: userRole == 'leader',
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('초대 코드 입력'),
            onTap: () => _enterConnectionCode(context),
            enabled: userRole != 'member',
          ),
          const Divider(),
          // 계정 관리 기능
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () => _handleLogout(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              '계정 삭제',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _handleDeleteAccount(context),
          ),
          if (userRole == 'leader' && relatedUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '멤버 관리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...relatedUsers
                      .map((memberUsername) => ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE0E0E0),
                              radius: 20, // 크기 조정
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF9E9E9E),
                                size: 24, // 크기 조정
                              ),
                            ),
                            title: Text(memberUsername),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: () => _removeMember(memberUsername),
                            ),
                          ))
                      .toList(),
                ],
              ),
            )
          else if (userRole == 'member')
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                '그룹 탈퇴',
                style: TextStyle(color: Colors.red),
              ),
              onTap: _leaveGroup,
            ),
        ],
      ),
    );
  }
}
