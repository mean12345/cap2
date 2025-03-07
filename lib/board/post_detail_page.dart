import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';

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
  List<dynamic> comments = [];
  VideoPlayerController? _videoPlayerController;
  bool _isIconVisible = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _fetchProfileInfo(widget.username);

    if (widget.post['video_url'] != null &&
        widget.post['video_url'].isNotEmpty) {
      print("Video URL: ${widget.post['video_url']}"); // URL 로그 확인
      _videoPlayerController =
          VideoPlayerController.network(widget.post['video_url'])
            ..initialize().then((_) {
              setState(() {}); // 초기화 완료 후 상태 업데이트
              print("Video initialized");
            }).catchError((error) {
              print("Error initializing video player: $error");
            });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _videoPlayerController?.dispose();
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

  Future<void> _deleteComment(int commentId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('댓글 삭제'),
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
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 400, // 상세 페이지에서 이미지 크기 제한
                          ),
                          width: double.infinity,
                          child: Image.network(
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
                        ),
                        const SizedBox(height: 16), // 하단 여백 추가
                      ],
                    ),

                  // 비디오 처리
                  if (widget.post['video_url'] != null &&
                      widget.post['video_url'].isNotEmpty)
                    Column(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 비디오 플레이어
                              _videoPlayerController != null &&
                                      _videoPlayerController!
                                          .value.isInitialized
                                  ? GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (_videoPlayerController!
                                              .value.isPlaying) {
                                            _videoPlayerController!.pause();
                                            _isIconVisible = true;
                                          } else {
                                            _videoPlayerController!.play();
                                            _isIconVisible = false;
                                            Future.delayed(
                                                const Duration(seconds: 3), () {
                                              if (mounted) {
                                                setState(() {
                                                  _isIconVisible = false;
                                                });
                                              }
                                            });
                                          }
                                        });
                                      },
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: double.infinity,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: SizedBox(
                                            width: _videoPlayerController!
                                                .value.size.width,
                                            height: _videoPlayerController!
                                                .value.size.height,
                                            child: VideoPlayer(
                                                _videoPlayerController!),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator()),

                              // 컨트롤 오버레이 (재생/일시정지 버튼)
                              if (_isIconVisible)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_videoPlayerController!
                                          .value.isPlaying) {
                                        _videoPlayerController!.pause();
                                      } else {
                                        _videoPlayerController!.play();
                                        Future.delayed(
                                            const Duration(seconds: 3), () {
                                          if (mounted) {
                                            setState(() {
                                              _isIconVisible = false;
                                            });
                                          }
                                        });
                                      }
                                    });
                                  },
                                  child: Icon(
                                    _videoPlayerController!.value.isPlaying
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),

                              // 하단 컨트롤바
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.5),
                                      ],
                                    ),
                                  ),
                                  child: VideoProgressIndicator(
                                    _videoPlayerController!,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: Colors.white,
                                      bufferedColor: Colors.white24,
                                      backgroundColor: Colors.grey,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                  ...comments
                      .map((comment) => ListTile(
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
                                  return profileInfo['profile_picture'] !=
                                              null &&
                                          profileInfo['profile_picture']!
                                              .isNotEmpty
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                              profileInfo['profile_picture']!),
                                        )
                                      : const Icon(Icons
                                          .person); // 프로필 이미지가 없을 경우 기본 아이콘 표시
                                } else {
                                  return const Icon(
                                      Icons.person); // 프로필 이미지가 없을 경우 기본 아이콘 표시
                                }
                              },
                            ),
                            title: FutureBuilder<Map<String, String>>(
                              future: _fetchProfileInfo(comment[
                                  'username']), // username에 해당하는 닉네임을 가져옴
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
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
                                  return const Text(
                                      '닉네임을 불러오는 중...'); // 닉네임이 없을 경우 표시
                                }
                              },
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(comment['content']),
                            ),
                            trailing: comment['username'] == widget.username
                                ? IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () =>
                                        _deleteComment(comment['comment_id']),
                                  )
                                : null,
                          ))
                      .toList(),
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
