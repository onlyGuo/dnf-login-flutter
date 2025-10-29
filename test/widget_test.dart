import 'package:flutter_test/flutter_test.dart';

import 'package:dnf_login_flutter/main.dart';

void main() {
  testWidgets('登录界面展示核心元素', (tester) async {
    await tester.pumpWidget(
      const LoginApp(
        enableCustomChrome: false,
        autoBootstrap: false,
      ),
    );
    await tester.pump();

    expect(find.text('DNF 台服登录器'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
    expect(find.text('注册'), findsWidgets);
  });
}
