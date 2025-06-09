import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/login/widget_login.dart';

class PasswordResetPage extends StatefulWidget {
  final String username;

  const PasswordResetPage({super.key, required this.username});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  Future<void> resetPassword() async {
    final String baseUrl = dotenv.get('BASE_URL');

    // 비밀번호 유효성 체크
    if (passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호와 비밀번호 확인을 모두 입력해주세요.')),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': widget.username,
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // 비밀번호 재설정 성공
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 재설정되었습니다.')),
        );
        Navigator.pop(context); // 이전 화면으로 돌아가기
      } else {
        // 서버 오류
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호 재설정에 실패했습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버와의 통신 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('비밀번호 재설정'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(45.0, 50.0, 45.0, 45.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '아이디: ${widget.username}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.olivegreen,
              ),
            ),
            const SizedBox(height: 20),
            buildPasswordTextField(),
            const SizedBox(height: 15),
            buildConfirmPasswordTextField(),
            const SizedBox(height: 20),
            buildResetPasswordButton(),
          ],
        ),
      ),
    );
  }

  Widget buildPasswordTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: passwordController,
        obscureText: true,
        decoration: InputDecoration(
          hintText: '새 비밀번호',
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

  Widget buildConfirmPasswordTextField() {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: confirmPasswordController,
        obscureText: true,
        decoration: InputDecoration(
          hintText: '새 비밀번호 확인',
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

  Widget buildResetPasswordButton() {
    return ElevatedButton(
      onPressed: resetPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.olivegreen,
        minimumSize: Size(double.infinity, 50),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Text(
        '비밀번호 변경',
        style: TextStyle(color: Colors.black, fontSize: 18),
      ),
    );
  }

  // Input field border styling
  OutlineInputBorder buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(
        color: color,
        width: width,
      ),
    );
  }

  // Shadow box styling for input fields
  BoxDecoration buildShadowBox() {
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.5),
          spreadRadius: 2,
          blurRadius: 5,
          offset: Offset(0, 3), // changes position of shadow
        ),
      ],
    );
  }
}
