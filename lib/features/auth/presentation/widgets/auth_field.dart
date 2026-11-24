import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';

/// 认证表单输入字段组件，支持密码显隐切换与服务端字段错误展示。
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.password = false,
    this.email = false,
    this.validator,
    this.serverError,
  });

  final String? serverError;
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
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
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
        errorText: widget.serverError,
        errorMaxLines: 3,
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _visible ? '隐藏密码' : '显示密码',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(_visible ? AppIcons.eyeSlash : AppIcons.eye),
              )
            : null,
      ),
    ),
  );
}

/// 校验基础邮箱地址格式；通过返回 `null`，不合法返回中文提示。
String? validateEmail(String? value) =>
    RegExp(r'^\S+@\S+\.\S+$').hasMatch(value?.trim() ?? '')
    ? null
    : '请输入有效的邮箱地址';
