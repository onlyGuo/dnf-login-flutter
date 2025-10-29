import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'services/api_client.dart';
import 'services/update_controller.dart';

const MethodChannel _windowControlChannel = MethodChannel('dnf/window_control');

bool _supportsCustomChrome() {
  if (kIsWeb) return false;
  try {
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return false;
    }
    final env = Platform.environment;
    if (env['FLUTTER_TEST'] == 'true') {
      return false;
    }
  } catch (_) {
    return false;
  }
  return true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final enableCustomChrome = _supportsCustomChrome();
  if (enableCustomChrome) {
    doWhenWindowReady(() {
      const initialSize = Size(420, 640);
      appWindow
        ..minSize = initialSize
        ..maxSize = initialSize
        ..size = initialSize
        ..alignment = Alignment.center
        ..title = 'DNF 登录器'
        ..show();
    });
  }
  runApp(LoginApp(enableCustomChrome: enableCustomChrome));
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.gradient,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    final colors = widget.gradient;
    final effectiveColors = colors
        .map(
          (color) => color.withOpacity(
            isDisabled
                ? 0.32
                : _hovering
                    ? 0.95
                    : 0.82,
          ),
        )
        .toList(growable: false);

    final boxShadow = _hovering && !isDisabled
        ? [
            BoxShadow(
              color: colors.last.withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ];

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:
            isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) {
          if (!isDisabled) {
            setState(() => _hovering = true);
          }
        },
        onExit: (_) {
          if (!isDisabled) {
            setState(() => _hovering = false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: effectiveColors),
              borderRadius: BorderRadius.circular(12),
              boxShadow: boxShadow,
              border: Border.all(
                color: Colors.white.withOpacity(isDisabled ? 0.05 : 0.14),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 18,
              color: Colors.white.withOpacity(isDisabled ? 0.4 : 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginApp extends StatelessWidget {
  const LoginApp({
    super.key,
    required this.enableCustomChrome,
    this.autoBootstrap = true,
  });

  final bool enableCustomChrome;
  final bool autoBootstrap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DNF 登录器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF22D3EE),
          surface: Color(0xFF0F172A),
          background: Color(0xFF0F172A),
        ),
        useMaterial3: true,
        textTheme: ThemeData.dark()
            .textTheme
            .apply(fontFamilyFallback: const ['Noto Sans CJK SC']),
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        cardColor: Colors.transparent,
        dialogBackgroundColor: const Color(0xFF111827),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6366F1)),
          ),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        snackBarTheme:
            const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      color: Colors.transparent,
      home: LoginScreen(
        enableCustomChrome: enableCustomChrome,
        autoBootstrap: autoBootstrap,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.enableCustomChrome,
    this.autoBootstrap = true,
  });

  final bool enableCustomChrome;
  final bool autoBootstrap;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiClient _apiClient = ApiClient();
  late final UpdateController _updateController = UpdateController(_apiClient);

  final TextEditingController _loginAccountController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _registerAccountController =
      TextEditingController();
  final TextEditingController _registerPasswordController =
      TextEditingController();
  final TextEditingController _registerConfirmController =
      TextEditingController();
  final TextEditingController _registerCaptchaController =
      TextEditingController();
  final TextEditingController _registerRecommenderController =
      TextEditingController();

  final PageController _carouselController =
      PageController(viewportFraction: 1);

  bool _loginLoading = false;
  bool _registerLoading = false;
  bool _captchaLoading = false;
  bool _bigPictureLoading = false;

  Uint8List? _captchaImage;
  String? _captchaUuid;
  List<BigPictureItem> _bigPictures = const [];
  UpdatePhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _updateController.addListener(_handleUpdateStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autoBootstrap) {
        return;
      }
      _updateController.checkAndUpdate();
      _loadBigPictures();
      _refreshCaptcha();
    });
  }

  @override
  void dispose() {
    _updateController.removeListener(_handleUpdateStateChanged);
    _updateController.dispose();
    _loginAccountController.dispose();
    _loginPasswordController.dispose();
    _registerAccountController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    _registerCaptchaController.dispose();
    _registerRecommenderController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _handleUpdateStateChanged() {
    if (!mounted) return;
    final state = _updateController.state;
    if (_lastPhase != state.phase) {
      _lastPhase = state.phase;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (state.phase == UpdatePhase.failed && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.phase == UpdatePhase.completed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.statusMessage ?? '更新完成')),
          );
        }
      });
    }
    setState(() {});
  }

  Future<void> _loadBigPictures() async {
    setState(() => _bigPictureLoading = true);
    try {
      final response = await _apiClient.fetchBigPictureList();
      final data = response.data;
      if (data is List) {
        final items = <BigPictureItem>[];
        for (final element in data) {
          if (element is Map) {
            final map = <String, dynamic>{};
            element.forEach((key, value) {
              map[key.toString()] = value;
            });
            items.add(BigPictureItem.fromJson(map));
          }
        }
        setState(() => _bigPictures = items);
      } else {
        setState(() => _bigPictures = const []);
      }
    } catch (_) {
      setState(() => _bigPictures = const []);
    } finally {
      if (mounted) {
        setState(() => _bigPictureLoading = false);
      }
    }
  }

  Future<void> _refreshCaptcha() async {
    setState(() {
      _captchaLoading = true;
      _captchaImage = null;
      _captchaUuid = const Uuid().v4();
    });
    final uuid = _captchaUuid!;
    try {
      final image = await _apiClient.fetchCaptcha(uuid);
      if (!mounted || _captchaUuid != uuid) return;
      setState(() => _captchaImage = image);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证码获取失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _captchaLoading = false);
      }
    }
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final account = _loginAccountController.text.trim();
    final password = _loginPasswordController.text.trim();
    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }
    setState(() => _loginLoading = true);
    try {
      final response =
          await _apiClient.login(account: account, password: password);
      final data = response.data;
      final payload = <String, dynamic>{};
      if (data is Map<String, dynamic>) {
        payload.addAll(data);
      } else if (data is Map) {
        for (final entry in data.entries) {
          payload[entry.key.toString()] = entry.value;
        }
      }

      final message = payload['message']?.toString() ?? '登录成功';
      final token = payload['token']?.toString();

      if (Platform.isWindows && token != null && token.isNotEmpty) {
        try {
          final result =
              await Process.run('cmd', ['/c', 'start', 'dnf.exe', token]);
          if (!mounted) return;
          if (result.exitCode != 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$message，但启动客户端失败 (code ${result.exitCode})'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$message，正在启动客户端...')),
            );
          }
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$message，但启动客户端失败: $error')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on DioException catch (error) {
      final message = error.response?.data?['message']?.toString() ??
          error.message ??
          '登录失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();
    final account = _registerAccountController.text.trim();
    final password = _registerPasswordController.text.trim();
    final confirm = _registerConfirmController.text.trim();
    final captcha = _registerCaptchaController.text.trim();
    final recommender = _registerRecommenderController.text.trim();
    final uuid = _captchaUuid;

    if (account.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty ||
        captcha.isEmpty ||
        uuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整注册信息')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的密码不一致')),
      );
      return;
    }

    setState(() => _registerLoading = true);
    try {
      final response = await _apiClient.register(
        account: account,
        password: password,
        validationIndex: uuid,
        captcha: captcha,
        recommender: recommender.isEmpty ? null : recommender,
      );
      final message = response.data?['message']?.toString() ?? '注册成功';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _registerCaptchaController.clear();
      _refreshCaptcha();
    } on DioException catch (error) {
      final message = error.response?.data?['message']?.toString() ??
          error.message ??
          '注册失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _refreshCaptcha();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注册失败: $error')),
      );
      _refreshCaptcha();
    } finally {
      if (mounted) {
        setState(() => _registerLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = _updateController.state;
    final windowShell = Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: updateState.shouldBlockUI,
            child: Center(
              child: DefaultTabController(
                length: 2,
                child: Container(
                  width: 420,
                  height: 640,
                  // padding: const EdgeInsets.only(left: 24, top: 0, right: 24, bottom: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E293B), Color(0xFF111827)],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitleBar(updateState),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildCarousel(),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTabBar(),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: TabBarView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildLoginForm(
                                  updateState.shouldBlockUI || _loginLoading),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildRegisterForm(
                                  updateState.shouldBlockUI ||
                                      _registerLoading),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (updateState.shouldBlockUI ||
              updateState.phase == UpdatePhase.failed)
            _buildUpdateOverlay(updateState),
        ],
      ),
    );
    return windowShell;
  }

  Widget _buildTitleBar(UpdateState updateState) {
    final controls = _buildWindowControls(updateState);

    Widget leading = _buildHeaderBranding(updateState);
    if (widget.enableCustomChrome) {
      leading = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _startDrag(),
        onDoubleTap: _toggleMaximize,
        child: Container(
          child: leading,
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Expanded(
            child: leading,
          ),
          Container(
            padding: const EdgeInsets.only(right: 20),
            child: controls,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBranding(UpdateState updateState) {
    final versionLabel = updateState.remoteVersion?.version;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '地下城与勇士',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                text: '稳定高速的一站式解决方案',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                ),
                children: versionLabel != null
                    ? [
                        TextSpan(
                          text: '  ·  ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: '版本 $versionLabel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                      ]
                    : const [],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowControls(UpdateState updateState) {
    final isBusy = updateState.isBusy;
    final allowWindowActions = widget.enableCustomChrome;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: Icons.remove,
          tooltip: '最小化',
          gradient: const [Color(0xFF1E293B), Color(0xFF334155)],
          onTap: allowWindowActions ? () => _minimizeWindow() : null,
        ),
        const SizedBox(width: 10),
        _WindowControlButton(
          icon: Icons.refresh_rounded,
          tooltip: '重新检查更新',
          gradient: const [Color(0xFF22D3EE), Color(0xFF38BDF8)],
          onTap: isBusy ? null : () => _updateController.checkAndUpdate(),
        ),
        const SizedBox(width: 10),
        _WindowControlButton(
          icon: Icons.close,
          tooltip: '退出',
          gradient: const [Color(0xFFF97316), Color(0xFFEF4444)],
          onTap: allowWindowActions ? _closeWindow : SystemNavigator.pop,
        ),
      ],
    );
  }

  Future<void> _minimizeWindow() async {
    var handled = false;
    if (widget.enableCustomChrome) {
      try {
        await _windowControlChannel.invokeMethod('minimize');
        handled = true;
      } catch (_) {}
    }
    if (!handled) {
      try {
        appWindow.minimize();
        handled = true;
      } catch (_) {}
    }
    if (!handled) {
      try {
        appWindow.hide();
        handled = true;
      } catch (_) {}
    }
    if (!handled) {
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  void _startDrag() {
    try {
      appWindow.startDragging();
    } catch (_) {
      // Ignore when running in environments without desktop windowing.
    }
  }

  void _toggleMaximize() {
    try {
      appWindow.maximizeOrRestore();
    } catch (_) {}
  }

  void _closeWindow() {
    try {
      appWindow.close();
    } catch (_) {
      SystemNavigator.pop();
    }
  }

  Widget _buildCarousel() {
    const placeholderHeight = 170.0;
    if (_bigPictureLoading) {
      return const SizedBox(
        height: placeholderHeight,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_bigPictures.isEmpty) {
      return Container(
        height: placeholderHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Center(
          child: Text(
            '精彩活动预览暂不可用',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ),
      );
    }
    return SizedBox(
      height: placeholderHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: PageView.builder(
          controller: _carouselController,
          itemCount: _bigPictures.length,
          itemBuilder: (context, index) {
            final item = _bigPictures[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image,
                        color: Colors.white54, size: 48),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF6366F1),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        tabs: const [
          Tab(text: '登录'),
          Tab(text: '注册'),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool disabled) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(
            controller: _loginAccountController,
            label: '账号',
            hint: '请输入账号',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _loginPasswordController,
            label: '密码',
            hint: '请输入密码',
            prefixIcon: Icons.lock_outline,
            obscure: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: disabled ? null : _submitLogin,
              child: _loginLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(bool disabled) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 5),
          _buildField(
            controller: _registerAccountController,
            label: '账号',
            hint: '请输入账号',
            prefixIcon: Icons.person_add_alt,
            dense: true,
          ),
          const SizedBox(height: 10),
          _buildField(
            controller: _registerPasswordController,
            label: '密码',
            hint: '请输入密码',
            prefixIcon: Icons.lock_outline,
            obscure: true,
            dense: true,
          ),
          const SizedBox(height: 10),
          _buildField(
            controller: _registerConfirmController,
            label: '确认密码',
            hint: '请再次输入密码',
            prefixIcon: Icons.lock_reset,
            obscure: true,
            dense: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: _registerCaptchaController,
                  label: '验证码',
                  hint: '输入验证码',
                  prefixIcon: Icons.verified_outlined,
                  dense: true,
                ),
              ),
              const SizedBox(width: 12),
              _buildCaptchaPreview(),
            ],
          ),
          const SizedBox(height: 10),
          _buildField(
            controller: _registerRecommenderController,
            label: '推荐人',
            hint: '请输入邀请人账号',
            prefixIcon: Icons.card_giftcard,
            dense: true,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: disabled ? null : _submitRegister,
            child: _registerLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('注册'),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptchaPreview() {
    return InkWell(
      onTap: _captchaLoading ? null : _refreshCaptcha,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 110,
        height: 35,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _captchaLoading
              ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _captchaImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _captchaImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : Center(
                      child: Text(
                        '点击刷新\n验证码',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildUpdateOverlay(UpdateState state) {
    final isError = state.phase == UpdatePhase.failed;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isError ? '更新失败' : '自动更新中',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (!isError) ...[
                  LinearProgressIndicator(
                    value: state.progress > 0 && state.progress <= 1
                        ? state.progress
                        : null,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.statusMessage ?? '请稍候...',
                    style: TextStyle(color: Colors.white.withOpacity(0.75)),
                    textAlign: TextAlign.center,
                  ),
                  if (state.remoteVersion?.description.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: Text(
                          state.remoteVersion!.description,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    state.errorMessage ?? '未知错误，请稍后重试',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _updateController.checkAndUpdate();
                    },
                    child: const Text('重新尝试'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscure = false,
    bool dense = false,
  }) {
    return Container(
      height: dense ? 35 : null,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autofillHints: obscure ? const [AutofillHints.password] : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(prefixIcon, color: Colors.white.withOpacity(0.75)),
          contentPadding: dense
              ? const EdgeInsets.symmetric(horizontal: 5, vertical: 18)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
