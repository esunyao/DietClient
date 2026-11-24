import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/diet_app.dart';

/// 应用入口，在顶层 Riverpod 容器中启动 [DietApp]。
void main() => runApp(const ProviderScope(child: DietApp()));
