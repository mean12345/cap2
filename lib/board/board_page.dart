import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'create_post_page.dart';
import 'post_detail_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart'; // 비디오 플레이어 패키지 추가

class BoardPage extends StatefulWidget {
  final String username;

  const BoardPage({super.key, required this.username});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  VideoPlayerController? _videoController;

  List<Map<String, dynamic>> posts = [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _videoController?.dispose();

    _commentController.dispose();
    super.dispose();
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> _showCommentDialog(int postId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 작성'),
        content: TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: '댓글을 입력하세요',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (_commentController.text.isNotEmpty) {
                await _addComment(postId, _commentController.text);
                _commentController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('작성'),
          ),
        ],
      ),
    );
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

  Future<void> _initializeVideoController(String videoUrl) async {
    print('Initializing video controller with URL: $videoUrl'); // 비디오 URL 로그
    try {
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController!.initialize();
      print('Video initialized successfully'); // 비디오 초기화 성공 로그
      setState(() {}); // 비디오 초기화 후 UI 갱신
    } catch (e) {
      print('Error initializing video: $e'); // 비디오 초기화 실패 로그
    }
  }

  Future<void> _addComment(int postId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'post_id': postId,
          'username': widget.username,
          'content': content,
        }),
      );

      if (response.statusCode == 201) {
        _loadPosts(); // 게시글과 댓글 새로고침
      } else {
        throw Exception('Failed to add comment');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 작성에 실패했습니다.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfileInfo(widget.username);

    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/${widget.username}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          posts = List<Map<String, dynamic>>.from(data);
        });
      } else {
        throw Exception('Failed to load posts');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글을 불러오는데 실패했습니다.')),
      );
    }
  }

  Future<void> _deletePost(int postId, String postUsername) async {
    // 삭제 확인 다이얼로그
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('정말 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': widget.username}),
      );

      if (response.statusCode == 200) {
        _loadPosts(); // 게시글 목록 새로고침
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글이 삭제되었습니다.')),
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
              : '게시글 삭제에 실패했습니다.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('게시판'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white, // AppBar 배경을 흰색으로 설정
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreatePostPage(username: widget.username),
                  ),
                );
                if (result == true) {
                  _loadPosts();
                }
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white, // 전체 배경을 흰색으로 설정
      body: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          if (post['video_url'] != null &&
              post['video_url'].toString().isNotEmpty) {
            if (_videoController == null ||
                _videoController!.dataSource != post['video_url']) {
              _initializeVideoController(post['video_url']);
            }
          }
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Color(0xFF4DA374), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: FutureBuilder<Map<String, String>>(
                    future: _fetchProfileInfo(post[
                        'username']), // username에 맞는 프로필 이미지 URL과 닉네임을 반환받음
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                        post['username']), // username에 해당하는 닉네임을 가져옴
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                            '닉네임을 불러오는 중...'); // 닉네임을 불러오는 중일 때 표시되는 텍스트
                      } else if (snapshot.hasError) {
                        return const Text('닉네임을 불러오는 데 실패했습니다.');
                      } else if (snapshot.hasData) {
                        final profileInfo = snapshot.data!;
                        return Text(
                          profileInfo['nickname'] ??
                              '닉네임을 불러오는 중...', // 닉네임을 불러온 경우
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      } else {
                        return const Text('닉네임을 불러오는 중...'); // 닉네임이 없을 경우 표시
                      }
                    },
                  ),
                  subtitle: Text(post['created_at']),
                  trailing: widget.username == post['username']
                      ? IconButton(
                          padding: const EdgeInsets.only(left: 8, top: 8),
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deletePost(
                            post['post_id'],
                            post['username'],
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Text(post['content']),
                ),
                if (post['video_url'] != null &&
                    post['video_url'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _videoController != null &&
                                  _videoController!.value.isInitialized
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 300,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width:
                                            _videoController!.value.size.width,
                                        height:
                                            _videoController!.value.size.height,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator()),
                          const Icon(
                            Icons.play_circle_outline,
                            size: 50,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (post['image_url'] != null &&
                    post['image_url'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: Image.network(
                        post['image_url'],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          print('Image error: $error');
                          return const Center(child: Text('이미지를 불러올 수 없습니다.'));
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      icon: const Icon(Icons.comment),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailPage(
                              post: post,
                              username: widget.username,
                            ),
                          ),
                        ).then((_) => _loadPosts());
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
