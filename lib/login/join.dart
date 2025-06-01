import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:dangq/login/widget_login.dart';
import 'package:dangq/login/login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Join extends StatefulWidget {
  const Join({super.key});

  @override
  State<Join> createState() => _JoinState();
}

class _JoinState extends BaseLoginState<Join> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('회원가입', style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, isKeyboardVisible ? 100 : 10),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 45.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildNicknameTextField(),
                    SizedBox(height: 7),
                    buildEmailTextField(),
                    SizedBox(height: 7),
                    buildIdTextField(),
                    SizedBox(height: 7),
                    buildPasswordTextField(),
                    SizedBox(height: 7),
                    buildPasswordAgainTextField(),
                    SizedBox(height: 7),
                    buildjoinButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 닉네임 입력
  Widget buildNicknameTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: usernameController,
        decoration: InputDecoration(
          hintText: '닉네임',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
        ),
      ),
    );
  }

  // 아이디 입력
  Widget buildIdTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: idController,
        decoration: InputDecoration(
          hintText: '아이디',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
        ),
      ),
    );
  }

  // 비밀번호 입력
  Widget buildPasswordTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: passwordController,
        obscureText: _isPasswordObscure,
        decoration: InputDecoration(
          hintText: '비밀번호',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
          suffixIcon: IconButton(
            icon: Icon(
                _isPasswordObscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () =>
                setState(() => _isPasswordObscure = !_isPasswordObscure),
          ),
        ),
      ),
    );
  }

  // 비밀번호 확인 입력
  Widget buildPasswordAgainTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: confirmPasswordController,
        obscureText: _isConfirmPasswordObscure,
        decoration: InputDecoration(
          hintText: '비밀번호 확인',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
          suffixIcon: IconButton(
            icon: Icon(_isConfirmPasswordObscure
                ? Icons.visibility_off
                : Icons.visibility),
            onPressed: () => setState(
                () => _isConfirmPasswordObscure = !_isConfirmPasswordObscure),
          ),
        ),
      ),
    );
  }

  // 이메일 입력
  Widget buildEmailTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: emailController,
        decoration: InputDecoration(
          hintText: '이메일',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          focusedBorder: buildInputBorder(AppColors.olivegreen, 2.0),
          enabledBorder: buildInputBorder(Colors.grey, 1.0),
        ),
      ),
    );
  }

  Widget buildjoinButton() {
    return ElevatedButton(
      onPressed: () async {
        // 회원가입 요청
        final baseUrl = dotenv.get('BASE_URL');
        final response = await http.post(
          Uri.parse('$baseUrl/users'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'nickname': usernameController.text,
            'email': emailController.text,
            'username': idController.text,
            'password': passwordController.text,
          }),
        );

        if (response.statusCode == 201) {
          // 성공적으로 회원가입 후 로그인 화면으로 이동
          Navigator.pop(context);
        } else {
          // 오류 처리
          final errorMessage =
              jsonDecode(response.body)['message'] ?? '회원가입 실패';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('회원가입 실패: $errorMessage')),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.olivegreen,
        minimumSize: Size(double.infinity, 50),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Text('회원가입', style: TextStyle(color: Colors.black, fontSize: 18)),
    );
  }
}
