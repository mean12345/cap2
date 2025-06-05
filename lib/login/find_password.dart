import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:dangq/login/widget_login.dart';
import 'package:dangq/login/login.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/login/password_reset_success.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FindPassword extends StatefulWidget {
  const FindPassword({super.key});

  @override
  State<FindPassword> createState() => _FindPasswordState();
}

class _FindPasswordState extends BaseLoginState<FindPassword> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController _certifyController = TextEditingController();

  Timer? timer;
  int timeLeft = 120;
  bool isTimerRunning = false;
  String timerText = '';
  bool isVerified = false;
  bool isSendingCode = true; // true일 때 '코드 보내기', false일 때 '인증하기' 표시

  void startTimer() {
    if (isTimerRunning) return;
    timeLeft = 120;
    isTimerRunning = true;
    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
          timerText =
              '${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}';
        } else {
          isTimerRunning = false;
          timer?.cancel();
          timerText = '';
          isSendingCode = true; // 타이머 종료 시 다시 코드 보내기 상태로
        }
      });
    });
  }

  void showErrorDialog(String message) {
    print("오류 발생: $message");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> sendVerificationCode() async {
    // 입력값 검증
    if (emailController.text.isEmpty || usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일과 아이디를 모두 입력해주세요.')),
      );
      return;
    }

    try {
      final String baseUrl = dotenv.get('BASE_URL');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-verification-email'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': emailController.text,
          'username': usernameController.text,
        }),
      );

      if (response.statusCode == 200) {
        // 성공
        startTimer();
        setState(() {
          isSendingCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증 코드가 이메일로 전송되었습니다.')),
        );
      } else {
        // 서버 응답 파싱
        try {
          final responseData = json.decode(response.body);
          String errorMessage = responseData['message'] ?? '서버 오류가 발생했습니다.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        } catch (e) {
          // JSON 파싱 실패 시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버와의 통신 중 오류가 발생했습니다.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버와의 통신 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

// 인증하기 버튼이 눌렸을 때
  Future<void> verifyCode() async {
    final String email = emailController.text;
    final String username = usernameController.text;
    final String code = _certifyController.text;
    final String baseUrl = dotenv.get('BASE_URL');

    // 인증 코드가 비어 있을 경우 경고 메시지
    if (code.isEmpty) {
      showErrorDialog('인증 코드를 입력해주세요.');
      print('인증 코드가 비어있음');
      return; // 인증 코드가 없으면 함수 종료
    }

    setState(() {
      isVerified = true;
    });

    try {
      print('인증 요청 시작: 이메일: $email, 사용자명: $username, 인증번호: $code'); // 디버그 로그

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-code'),
        body: json.encode({
          'email': email,
          'code': code,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print('응답 상태 코드: ${response.statusCode}'); // 디버그 로그
      print('응답 본문: ${response.body}'); // 디버그 로그

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            isVerified = true;
            isTimerRunning = false;
            timer?.cancel();
            timerText = '';
          });
          print('인증번호 확인 성공');
        } else {
          showErrorDialog('잘못된 인증번호입니다.');
          print('인증번호 확인 실패: 잘못된 인증번호');
        }
      } else {
        showErrorDialog('서버 오류');
        print('서버 오류 발생: 상태 코드 ${response.statusCode}');
        print('서버 응답 본문: ${response.body}'); // 추가된 디버그 로그
      }
    } catch (e) {
      showErrorDialog('네트워크 오류');
      print("네트워크 오류 발생: $e");
    } finally {
      setState(() {
        // 인증 여부와 상태 관리
        isVerified = true;
      });
    }
  }

// 비밀번호 찾기 버튼 클릭 후 비밀번호 재설정 화면으로 이동
  Future<void> resetPassword() async {
    if (!isVerified) return;

    // 바로 PasswordResetPage로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PasswordResetPage(username: usernameController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          '비밀번호 찾기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey[100],
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, isKeyboardVisible ? 30 : -40),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 45.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildEmailTextField(),
                    const SizedBox(height: 7),
                    buildIdTextField(),
                    const SizedBox(height: 7),
                    buildCertifyTextField(),
                    const SizedBox(height: 7),
                    buildFindPasswordButton(),
                    const SizedBox(height: 8),
                    buildIdBottomLinks(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmailTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: emailController,
        decoration: InputDecoration(
          hintText: '이메일',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
        ),
      ),
    );
  }

  Widget buildIdTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: usernameController,
        decoration: InputDecoration(
          hintText: '아이디',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
        ),
      ),
    );
  }

  Widget buildCertifyTextField() {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: buildShadowBox(),
                child: TextField(
                  controller: _certifyController,
                  decoration: InputDecoration(
                    hintText: '인증번호',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
                    enabledBorder: buildInputBorder(Colors.grey, 1.0),
                    suffixIcon: isVerified
                        ? Icon(Icons.check_circle,
                            color: Colors.green) // 인증 성공시 체크 아이콘 표시
                        : (isTimerRunning
                            ? Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Text(
                                  timerText,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              )
                            : null),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        Container(
          decoration: buildShadowBox(),
          child: ElevatedButton(
            onPressed: () {
              if (isSendingCode) {
                sendVerificationCode();
              } else {
                verifyCode();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.limegreen,
              minimumSize: Size(100, 50),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Text(isSendingCode ? '코드 보내기' : '인증하기',
                style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget buildFindPasswordButton() {
    return ElevatedButton(
      onPressed: isVerified ? resetPassword : null, // 인증 성공 시 비밀번호 찾기 버튼 활성화
      style: ElevatedButton.styleFrom(
        backgroundColor: isVerified ? AppColors.olivegreen : Colors.grey,
        minimumSize: Size(double.infinity, 50),
        elevation: isVerified ? 10 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Text(
        '비밀번호 찾기',
        style: TextStyle(
            color: isVerified ? Colors.black : Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    usernameController.dispose();
    emailController.dispose();
    _certifyController.dispose();
    super.dispose();
  }
}
