import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:flutter/gestures.dart';
import 'package:dangq/login/widget_login.dart';
import 'package:dangq/login/login.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dangq/login/login.dart';

class FindId extends StatefulWidget {
  const FindId({super.key});

  @override
  State<FindId> createState() => _FindIdState();
}

class _FindIdState extends BaseLoginState<FindId> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController _certifyController = TextEditingController();

  Timer? timer;
  int timeLeft = 120;
  bool isTimerRunning = false;
  String timerText = '';
  bool isCodeSent = false;
  bool isCodeVerified = false;
  bool isVerifying = false;

  // 인증하기 타이머 관련 함수들
  void startTimer() {
    if (isTimerRunning) return;
    timeLeft = 120;
    isTimerRunning = true;
    timer?.cancel();
    print("타이머 시작");
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
          timerText =
              '${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}';
        } else {
          isTimerRunning = false;
          isCodeSent = false;
          timer?.cancel();
          timerText = '';
          print("타이머 종료");
        }
      });
    });
  }

  // 인증번호 전송
  Future<void> sendVerificationEmail(String email) async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      print("인증번호 이메일 전송 시작");
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-verification-email'),
        body: json.encode({'email': email}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            isCodeSent = true;
            isCodeVerified = false;
          });
          print('인증번호 이메일 전송 성공');
        } else {
          showErrorDialog('인증번호 전송 실패: ${data['message']}');
        }
      } else {
        showErrorDialog('서버 오류');
      }
    } catch (e) {
      showErrorDialog('네트워크 오류');
      print("네트워크 오류 발생: $e");
    }
  }

  // 인증번호 확인
  Future<void> verifyCode() async {
    if (!isCodeSent) {
      showErrorDialog('먼저 인증번호를 전송해주세요.');
      return;
    }

    final String email = emailController.text;
    final String code = _certifyController.text;
    final String baseUrl = dotenv.get('BASE_URL');

    setState(() {
      isVerifying = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-code'),
        body: json.encode({
          'email': email,
          'code': code,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            isCodeVerified = true;
            isTimerRunning = false;
            timer?.cancel();
            timerText = '';
          });
          print('인증번호 확인 성공');
        } else {
          showErrorDialog('잘못된 인증번호입니다.');
        }
      } else {
        showErrorDialog('서버 오류');
      }
    } catch (e) {
      showErrorDialog('네트워크 오류');
      print("네트워크 오류 발생: $e");
    } finally {
      setState(() {
        isVerifying = false;
      });
    }
  }

  // 아이디 찾기 함수
  Future<void> findId() async {
    if (!isCodeVerified) {
      showErrorDialog('이메일 인증을 먼저 완료해주세요.');
      return;
    }

    final String email = emailController.text;
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      print("아이디 찾기 요청 시작");
      final response = await http.post(
        Uri.parse('$baseUrl/auth/find-id'),
        body: json.encode({
          'email': email,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          print("아이디 찾기 성공: ${data['user_id']}");
          showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '아이디 찾기 성공',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text('아이디: ${data['user_id']}'),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // 다이얼로그 닫기
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Login(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          showErrorDialog('아이디 찾기 실패: ${data['message']}');
        }
      } else {
        showErrorDialog('서버 오류');
      }
    } catch (e) {
      showErrorDialog('네트워크 오류');
      print("아이디 찾기 네트워크 오류 발생: $e");
    }
  }

  void showErrorDialog(String message) {
    print("오류 발생: $message");
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                '오류',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 25),
              Text(message),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    child: Text(
                      '확인',
                      style: TextStyle(color: AppColors.green),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          '아이디 찾기',
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(45.0, 72.0, 45.0, 45.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildEmailTextField(emailController), //이메일 입력 박스
                const SizedBox(height: 7),
                buildCertifyTextField(), //인증번호 입력 박스
                const SizedBox(height: 7),
                buildFindIdButton(), //아이디 찾기 버튼
                const SizedBox(height: 8),
                buildPasswordBottomLinks(), //비밀번호 입력 버튼
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print("타이머와 컨트롤러 해제");
    timer?.cancel();
    emailController.dispose();
    _certifyController.dispose();
    super.dispose();
  }

  Widget buildEmailTextField(TextEditingController controller) {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: controller,
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

  Widget buildFindIdButton() {
    return ElevatedButton(
      onPressed: isCodeVerified ? findId : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isCodeVerified ? AppColors.olivegreen : Colors.grey,
        minimumSize: Size(double.infinity, 50),
        elevation: isCodeVerified ? 10 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Text('아이디 찾기',
          style: TextStyle(
              color: isCodeVerified ? Colors.black : Colors.white,
              fontSize: 18)),
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
                  scrollPadding: const EdgeInsets.only(bottom: 40), // 추가
                  decoration: InputDecoration(
                    hintText: '인증번호',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
                    enabledBorder: buildInputBorder(Colors.grey, 1.0),
                    suffixIcon: isCodeVerified
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : (isTimerRunning
                            ? Text(
                                timerText,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
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
            onPressed: isVerifying
                ? null
                : (isCodeSent
                    ? verifyCode
                    : () {
                        final String email = emailController.text;
                        if (email.isNotEmpty) {
                          sendVerificationEmail(email);
                          startTimer();
                        } else {
                          showErrorDialog('이메일을 입력해주세요.');
                        }
                      }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.limegreen,
              minimumSize: Size(100, 50),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Text(
              isCodeSent ? '인증하기' : '코드 보내기',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
