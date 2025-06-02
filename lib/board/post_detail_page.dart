import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String username;

  const PostDetailPage({
    super.key,
    required this.post,
    required this.username,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<dynamic> comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
    _fetchProfileInfo(widget.username);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> _loadComments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comments/posts/${widget.post['post_id']}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          comments = jsonDecode(response.body);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글을 불러오는데 실패했습니다.')),
      );
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'post_id': widget.post['post_id'],
          'username': widget.username,
          'content': _commentController.text,
        }),
      );

      if (response.statusCode == 201) {
        _commentController.clear();
        _loadComments();
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
        // 포커스 노드에서 포커스 제거
        _commentFocusNode.unfocus();
      } else {
        throw Exception('Failed to add comment');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 작성에 실패했습니다.')),
      );
    }
  }

  Future<Map<String, String>> _fetchProfileInfo(String username) async {
    final String baseUrl = dotenv.get('BASE_URL');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=$username'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'nickname': jsonResponse['nickname'] ?? '',
          'profile_picture': jsonResponse['profile_picture'] ?? '',
        };
      } else {
        throw Exception('프로필 정보 불러오기 실패');
      }
    } catch (e) {
      throw Exception('프로필 정보 불러오기 실패: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    // 키보드 숨기기
    FocusScope.of(context).unfocus();

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
                  '삭제 확인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text('이 댓글을 삭제하시겠습니까?'),
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

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': widget.username}),
      );

      if (response.statusCode == 200) {
        _loadComments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 삭제되었습니다.')),
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
              : '댓글 삭제에 실패했습니다.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('게시글'),
        backgroundColor: Colors.white, // 흰색 배경 설정
        foregroundColor: Colors.black, // 아이콘 및 텍스트 색상 설정
      ),
      backgroundColor: Colors.white, // 전체 배경 흰색 설정

      body: Column(
        children: [
          // 게시글 내용
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: FutureBuilder<Map<String, String>>(
                      future: _fetchProfileInfo(widget.post[
                          'username']), // 작성자의 username을 기준으로 프로필 이미지 URL과 닉네임을 불러옴
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircleAvatar(
                            child:
                                CircularProgressIndicator(), // 로딩 중에는 로딩 아이콘 표시
                          );
                        } else if (snapshot.hasError) {
                          return const CircleAvatar(
                            child: Icon(Icons.person), // 오류 발생 시 기본 아이콘 표시
                          );
                        } else if (snapshot.hasData) {
                          final profileInfo = snapshot.data!;
                          if (profileInfo['profile_picture'] != null &&
                              profileInfo['profile_picture']!.isNotEmpty) {
                            return CircleAvatar(
                              backgroundImage: NetworkImage(profileInfo[
                                  'profile_picture']!), // 프로필 이미지 표시
                            );
                          } else {
                            return const Icon(
                                Icons.person); // 프로필 이미지가 없을 경우 기본 아이콘 표시
                          }
                        } else {
                          return const Icon(
                              Icons.person); // 프로필 이미지가 없을 경우 기본 아이콘 표시
                        }
                      },
                    ),
                    title: FutureBuilder<Map<String, String>>(
                      future: _fetchProfileInfo(widget
                          .post['username']), // 작성자의 username에 해당하는 닉네임을 가져옴
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(''); // 로딩 중일 때는 빈 텍스트 표시
                        } else if (snapshot.hasError) {
                          return const Text('닉네임을 불러오는 데 실패했습니다.');
                        } else if (snapshot.hasData) {
                          final profileInfo = snapshot.data!;
                          return Text(
                            profileInfo['nickname'] ??
                                '', // 닉네임이 없을 경우 빈 문자열 표시
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        } else {
                          return const Text(''); // 데이터가 없을 경우 빈 텍스트 표시
                        }
                      },
                    ),
                    subtitle:
                        Text(widget.post['created_at'] ?? '시간 정보를 불러올 수 없습니다.'),
                  ),

                  // 게시글 내용
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.post['content'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  // 이미지가 있을 때
                  if (widget.post['image_url'] != null &&
                      widget.post['image_url'].toString().isNotEmpty)
                    Column(
                      children: [
                        Image.network(
                          widget.post['image_url'],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            print('Image error: $error');
                            return const Center(
                              child: Text('이미지를 불러올 수 없습니다.'),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16), // 하단 여백 추가
                      ],
                    ),

                  // 구분선
                  const Divider(height: 1),
                  // 댓글 목록
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '댓글 ${comments.length}개',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics:
                        NeverScrollableScrollPhysics(), // 부모 스크롤뷰를 따라가도록 설정
                    itemCount: comments.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.grey[200],
                      height: 1,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return ListTile(
                        leading: FutureBuilder<Map<String, String>>(
                          future: _fetchProfileInfo(comment[
                              'username']), // username에 맞는 프로필 이미지 URL과 닉네임을 반환받음
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircleAvatar(
                                child: CircularProgressIndicator(),
                              ); // 로딩 중에는 로딩 아이콘 표시
                            } else if (snapshot.hasError) {
                              return const CircleAvatar(
                                child: Icon(Icons.person),
                              ); // 오류 발생 시 기본 아이콘 표시
                            } else if (snapshot.hasData) {
                              final profileInfo = snapshot.data!;
                              // 프로필 이미지가 있으면 이미지로, 없으면 기본 아이콘 표시
                              return profileInfo['profile_picture'] != null &&
                                      profileInfo['profile_picture']!.isNotEmpty
                                  ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                          profileInfo['profile_picture']!),
                                    )
                                  : const Icon(
                                      Icons.person); // 프로필 이미지가 없을 경우 기본 아이콘 표시
                            } else {
                              return const Icon(
                                  Icons.person); // 프로필 이미지가 없을 경우 기본 아이콘 표시
                            }
                          },
                        ),
                        title: FutureBuilder<Map<String, String>>(
                          future: _fetchProfileInfo(
                              comment['username']), // username에 해당하는 닉네임을 가져옴
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text(''); // 로딩 중일 때는 빈 텍스트 표시
                            } else if (snapshot.hasError) {
                              return const Text('닉네임을 불러오는 데 실패했습니다.');
                            } else if (snapshot.hasData) {
                              final profileInfo = snapshot.data!;
                              return Row(
                                children: [
                                  Text(
                                    profileInfo['nickname'] ??
                                        '', // 닉네임이 없을 경우 빈 문자열 표시
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment['created_at'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return const Text(''); // 데이터가 없을 경우 빈 텍스트 표시
                            }
                          },
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(comment['content']),
                        ),
                        trailing: comment['username'] == widget.username
                            ? IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: () {
                                  // 키보드 숨기기
                                  FocusScope.of(context).unfocus();
                                  // 약간의 지연 후 삭제 다이얼로그 표시
                                  Future.delayed(Duration.zero, () {
                                    _deleteComment(comment['comment_id']);
                                  });
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 댓글 입력
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    autofocus: false,
                    decoration: const InputDecoration(
                      hintText: '댓글을 입력하세요',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
