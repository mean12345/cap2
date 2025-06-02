import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/pages/main/main_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/login/widget_login.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  BaseLoginState<Login> createState() => _LoginState();
}

class _LoginState extends BaseLoginState<Login> {
  // 컨트롤러를 상태로 선언
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Transform.translate(
        offset: Offset(0,
            isKeyboardVisible ? 100 : 60), //입력창 누르면 위로 올라가기 그리고 입력창 안 눌렀을때 위치치
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 45.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildIdTextField(), //아이디 입력 박스
                const SizedBox(height: 7),
                buildPasswordTextField(), //비밀번호 입력 박스
                const SizedBox(height: 7),
                buildLoginButton(), //로그인 버튼
                const SizedBox(height: 8),
                buildIdpasswordBottomLinks(), //아이디, 비밀번호 찾기
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 아이디 입력 필드
  Widget buildIdTextField() {
    return Container(
      decoration: buildShadowBox(), //그림자 박스
      child: TextField(
        controller: usernameController, // 클래스 상태로 선언한 컨트롤러 사용
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

  // 비밀번호 입력 필드
  Widget buildPasswordTextField() {
    return Container(
      decoration: buildShadowBox(), //그림자 박스
      child: TextField(
        controller: passwordController, // 클래스 상태로 선언한 컨트롤러 사용
        obscureText: _isObscure,
        decoration: InputDecoration(
          hintText: '비밀번호',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
          suffixIcon: IconButton(
            icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ),
        ),
      ),
    );
  }

  // 로그인 버튼
  Widget buildLoginButton() {
    return ElevatedButton(
      onPressed: () async {
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
        
        // 키보드가 완전히 내려갈 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 100));

        final String baseUrl = dotenv.get('BASE_URL');

        final response = await http.post(
          Uri.parse('$baseUrl/users/login'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'username': usernameController.text,
            'password': passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          // 키보드가 완전히 내려간 후 메인 화면으로 이동
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainPage(
                  username: usernameController.text,
                ),
              ),
            );
          }
        } else {
          // 오류 처리
          final errorMessage = jsonDecode(response.body)['message'] ?? '로그인 실패';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('로그인 실패: $errorMessage')),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.olivegreen,
        minimumSize: const Size(double.infinity, 50),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: const Text(
        '로그인',
        style: TextStyle(color: Colors.black, fontSize: 18),
      ),
    );
  }
}
