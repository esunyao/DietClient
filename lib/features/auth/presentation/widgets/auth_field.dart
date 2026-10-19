import 'package:flutter/material.dart';

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.password = false,
    this.email = false,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final bool password;
  final bool email;
  final String? Function(String?)? validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: widget.controller,
      obscureText: widget.password && !_visible,
      autocorrect: !widget.password && !widget.email,
      enableSuggestions: !widget.password,
      keyboardType: widget.email
          ? TextInputType.emailAddress
          : TextInputType.text,
      textInputAction: TextInputAction.next,
      validator:
          widget.validator ??
          (value) => value == null || value.trim().isEmpty
              ? '请填写${widget.label}'
              : null,
      decoration: InputDecoration(
        labelText: widget.label,
        errorMaxLines: 3,
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _visible ? '隐藏密码' : '显示密码',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
    ),
  );
}

String? validateEmail(String? value) =>
    RegExp(r'^\S+@\S+\.\S+$').hasMatch(value?.trim() ?? '')
    ? null
    : '请输入有效的邮箱地址';
