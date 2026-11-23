import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/diet_app.dart';

/// @brief 在顶层状态容器中启动应用。
/// @details 会话恢复和路由装配由 DietApp 负责。
void main() => runApp(const ProviderScope(child: DietApp()));
