import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:dangq/login/widget_login.dart';
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
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 레이아웃 변경 방지
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          '회원가입',
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
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 45,
                right: 45,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  SizedBox(height: 20),
                  buildjoinButton(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNicknameTextField() => buildTextField(usernameController, '닉네임');
  Widget buildEmailTextField() => buildTextField(emailController, '이메일');
  Widget buildIdTextField() => buildTextField(idController, '아이디');

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
            icon: Icon(_isPasswordObscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _isPasswordObscure = !_isPasswordObscure),
          ),
        ),
      ),
    );
  }

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
            icon: Icon(_isConfirmPasswordObscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _isConfirmPasswordObscure = !_isConfirmPasswordObscure),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(TextEditingController controller, String hintText) {
    return Container(
      decoration: buildShadowBox(),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
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
        final baseUrl = dotenv.get('BASE_URL');
        final response = await http.post(
          Uri.parse('$baseUrl/users'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'nickname': usernameController.text,
            'email': emailController.text,
            'username': idController.text,
            'password': passwordController.text,
          }),
        );

        if (response.statusCode == 201) {
          Navigator.pop(context);
        } else {
          final errorMessage = jsonDecode(response.body)['message'] ?? '회원가입 실패';
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
