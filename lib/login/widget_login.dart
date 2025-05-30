//로그인, 아이디 찾기, 비밀번호 찾기, 회원가입 페이지에서 쓰이는 위젯 모음
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dangq/login/find_id.dart';
import 'package:dangq/login/find_password.dart';
import 'package:dangq/login/join.dart';

abstract class BaseLoginState<T extends StatefulWidget> extends State<T> {
  //비번 숨김 여부
  @override
  void dispose() {
    super.dispose();
  }

  //로그인 페이지의 아이디, 비번 찾기 / 회원가입 위젯
  Widget buildIdpasswordBottomLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '아이디',
                style: TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FindId()),
                    );
                  },
              ),
              TextSpan(
                text: '/비밀번호 찾기',
                style: TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FindPassword()),
                    );
                  },
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Join()), // Join 페이지로 이동
            );
          },
          style: clearButtonStyle(),
          child: Text('회원가입', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  //회원가입입 페이지의 아이디, 비번 찾기 위젯
  Widget buildNojoinBottomLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '아이디',
                style: TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FindId()),
                    );
                  },
              ),
              TextSpan(
                text: '/비밀번호 찾기',
                style: TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FindPassword()),
                    );
                  },
              ),
            ],
          ),
        ),
      ],
    );
  }

  //비밀번호 찾기 페이지의 아이디 찾기, 회원가입 위젯
  Widget buildIdBottomLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {},
          style: clearButtonStyle(),
          child: RichText(
            text: TextSpan(
              children: [
                _buildTextSpanid('아이디 찾기', context),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Join()), // Join 페이지로 이동
            );
          },
          style: clearButtonStyle(),
          child: Text('회원가입', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  //아이디 찾기 페이지의 비밀번호 찾기, 회원가입 위젯
  Widget buildPasswordBottomLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {},
          style: clearButtonStyle(),
          child: RichText(
            text: TextSpan(
              children: [
                _buildTextSpanidpassward('비밀번호 찾기', context),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Join()), // Join 페이지로 이동
            );
          },
          style: clearButtonStyle(),
          child: Text('회원가입', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  //박스의 그림자
  BoxDecoration buildShadowBox() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  //텍스트 필드 테두리
  OutlineInputBorder buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
    );
  }

  //버튼 스타일
  ButtonStyle clearButtonStyle() {
    return ButtonStyle(
      splashFactory: NoSplash.splashFactory,
      overlayColor: MaterialStateProperty.all(Colors.transparent),
    );
  }

  //아이디 찾기, 비번찾기 시 이동
  TextSpan _buildTextSpanid(String text, BuildContext context) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FindId()),
          );
        },
    );
  }

  //비번 찾기, 아이디 찾기 시 이동
  TextSpan _buildTextSpanidpassward(String text, BuildContext context) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FindPassword()),
          );
        },
    );
  }
}
