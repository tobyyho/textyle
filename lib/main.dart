import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack.toString());
  };

  runApp(const TextyleApp());
}

class TextyleApp extends StatelessWidget {
  const TextyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'textyle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthPage(),
    );
  }
}

/// ---------- Shared theme ----------
class AppColors {
  static const bg = Color(0xFFF7F5F1);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFFCFBF8);

  static const primary = Color(0xFF0B7A69);
  static const primaryDark = Color(0xFF075F52);
  static const secondary = Color(0xFF234E7E);

  static const textDark = Color(0xFF1E1F22);
  static const textMuted = Color(0xFF7A7D82);
  static const hint = Color(0xFF9DA0A6);
  static const border = Color(0xFFE2DED7);

  static const rail = Color(0xFFD4CFC7);
  static const connector = Color(0xFFB2ACA3);

  static const navBg = Colors.transparent;
  static const shadow = Color(0x14000000);

  static const fieldFill = Color(0xFFFFFFFF);
}

BoxDecoration appBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFFF7F5F1),
        Color(0xFFF5F2ED),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

InputDecoration modernFieldDecoration({
  required String hint,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.hint,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: AppColors.surface,
    prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 22),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.border, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

/// ---------- One page at a time physics ----------
class OnePageAtATimeScrollPhysics extends PageScrollPhysics {
  const OnePageAtATimeScrollPhysics({super.parent});

  @override
  OnePageAtATimeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OnePageAtATimeScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final double page = position.pixels / position.viewportDimension;
    final double currentPage = page.roundToDouble();
    double targetPage = currentPage;

    if (velocity > tolerance.velocity) {
      targetPage = currentPage + 1;
    } else if (velocity < -tolerance.velocity) {
      targetPage = currentPage - 1;
    } else {
      final deltaFromRounded = page - currentPage;
      if (deltaFromRounded > 0.15) {
        targetPage = currentPage + 1;
      } else if (deltaFromRounded < -0.15) {
        targetPage = currentPage - 1;
      }
    }

    return targetPage * position.viewportDimension;
  }
}

/// ---------- Auth page ----------
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isSignUp = false;
  bool showPassword = false;
  bool rememberMe = true;
  bool showAuthContent = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final _formScrollController = ScrollController();

  final GlobalKey<_ClosetHeroHeaderState> _heroKey =
      GlobalKey<_ClosetHeroHeaderState>();

  void _handleRackIntroComplete() {
    if (!mounted || showAuthContent) return;
    setState(() {
      showAuthContent = true;
    });
  }

  void _goToMainApp() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  void _switchToSignUp() {
    FocusScope.of(context).unfocus();
    setState(() {
      isSignUp = true;
      showPassword = false;
    });
    _heroKey.currentState?.spinCounterClockwise();
  }

  void _switchToLogin() {
    FocusScope.of(context).unfocus();
    setState(() {
      isSignUp = false;
      showPassword = false;
    });
    _heroKey.currentState?.spinClockwise();
  }

  void _ensureFieldVisible(BuildContext fieldContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
      );
    });
  }

  Widget _buildLoginCard() {
    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            key: const ValueKey('login-card'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.76),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Username",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (fieldContext) {
                    return TextField(
                      controller: emailController,
                      textInputAction: TextInputAction.next,
                      onTap: () => _ensureFieldVisible(fieldContext),
                      decoration: modernFieldDecoration(
                        hint: "Enter your username",
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (fieldContext) {
                    return TextField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      textInputAction: TextInputAction.done,
                      onTap: () => _ensureFieldVisible(fieldContext),
                      onSubmitted: (_) => _goToMainApp(),
                      decoration: modernFieldDecoration(
                        hint: "••••••••••••",
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.92,
                          child: Checkbox(
                            value: rememberMe,
                            onChanged: (value) {
                              setState(() {
                                rememberMe = value ?? false;
                              });
                            },
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            side: const BorderSide(
                              color: AppColors.border,
                              width: 1.2,
                            ),
                          ),
                        ),
                        const Text(
                          "Remember me",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "Forgot password?",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _goToMainApp,
                    child: const Text(
                      "Sign In",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpCard() {
    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            key: const ValueKey('signup-card'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.76),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Name",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (fieldContext) {
                    return TextField(
                      textInputAction: TextInputAction.next,
                      onTap: () => _ensureFieldVisible(fieldContext),
                      decoration: modernFieldDecoration(
                        hint: "Enter your full name",
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  "Email",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (fieldContext) {
                    return TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onTap: () => _ensureFieldVisible(fieldContext),
                      decoration: modernFieldDecoration(
                        hint: "Enter your email",
                        prefixIcon: Icons.email_outlined,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  "Username",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (fieldContext) {
                    return TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      onTap: () => _ensureFieldVisible(fieldContext),
                      decoration: modernFieldDecoration(
                        hint: "Choose a username",
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (fieldContext) {
                    return TextField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      textInputAction: TextInputAction.done,
                      onTap: () => _ensureFieldVisible(fieldContext),
                      onSubmitted: (_) => _goToMainApp(),
                      decoration: modernFieldDecoration(
                        hint: "Create a password",
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _goToMainApp,
                    child: const Text(
                      "Create Account",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandBlock() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      opacity: showAuthContent ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: showAuthContent ? Offset.zero : const Offset(0, 0.05),
        child: IgnorePointer(
          ignoring: !showAuthContent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 18),
                SizedBox(
                  height: 70,
                  child: Image.asset(
                    'assets/textyle_logo.png',
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.checkroom_rounded,
                        color: AppColors.primary,
                        size: 48,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "more than just a walk-in",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthSection() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      opacity: showAuthContent ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: showAuthContent ? Offset.zero : const Offset(0, 0.05),
        child: IgnorePointer(
          ignoring: !showAuthContent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.025, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: isSignUp ? _buildSignUpCard() : _buildLoginCard(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isSignUp
                        ? "Already have an account? "
                        : "Don't have an account? ",
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: isSignUp ? _switchToLogin : _switchToSignUp,
                    child: Text(
                      isSignUp ? "Log in" : "Sign up",
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: appBackground(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      ClosetHeroHeader(
                        key: _heroKey,
                        onIntroComplete: _handleRackIntroComplete,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
  child: AnimatedPadding(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBrandBlock(),
        const SizedBox(height: 10),
        _buildAuthSection(),
      ],
    ),
  ),
),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------- Closet intro ----------
enum GarmentType { shirt, hoodie, jacket }

class ClosetHeroHeader extends StatefulWidget {
  final VoidCallback? onIntroComplete;

  const ClosetHeroHeader({
    super.key,
    this.onIntroComplete,
  });

  @override
  State<ClosetHeroHeader> createState() => _ClosetHeroHeaderState();
}

class _ClosetHeroHeaderState extends State<ClosetHeroHeader>
    with SingleTickerProviderStateMixin {
  static const double _itemExtent = 68.0;
  static const int _virtualItemCount = 50000;
  static const int _centerIndex = _virtualItemCount ~/ 2;
  static const Duration _introDuration = Duration(milliseconds: 2200);

  late final ScrollController _scrollController;
  late final AnimationController _momentumController;

  bool _didPlayIntro = false;
  bool _didRevealAuth = false;
  bool _isUserDragging = false;

  Future<void> _spinQueue = Future.value();

  double _dragVelocity = 0.0;
  DateTime? _lastDragTime;
  double? _lastDragDx;

  final List<_GarmentData> _garments = const [
    _GarmentData(color: Color(0xFF6C8C7A), type: GarmentType.shirt),
    _GarmentData(color: Color(0xFF0B7A69), type: GarmentType.hoodie),
    _GarmentData(color: Color(0xFF234E7E), type: GarmentType.jacket),
    _GarmentData(color: Color(0xFF9F8C7A), type: GarmentType.jacket),
    _GarmentData(color: Color(0xFFB7C6D9), type: GarmentType.shirt),
    _GarmentData(color: Color(0xFF5E6A72), type: GarmentType.jacket),
    _GarmentData(color: Color(0xFF7A8F6C), type: GarmentType.shirt),
    _GarmentData(color: Color(0xFFC5B49E), type: GarmentType.hoodie),
    _GarmentData(color: Color(0xFF8A6D5B), type: GarmentType.jacket),
    _GarmentData(color: Color(0xFF4E7C61), type: GarmentType.shirt),
    _GarmentData(color: Color(0xFF7FA7C7), type: GarmentType.shirt),
    _GarmentData(color: Color(0xFFA68E7A), type: GarmentType.jacket),
    _GarmentData(color: Color(0xFFAFCDBF), type: GarmentType.shirt),
    _GarmentData(color: Color(0xFF2F63A3), type: GarmentType.hoodie),
    _GarmentData(color: Color(0xFFD7D2CB), type: GarmentType.shirt),
  ];

  void spinClockwise() {
    _queueSpin(-4.2);
  }

  void spinCounterClockwise() {
    _queueSpin(4.2);
  }

  void _queueSpin(double itemDelta) {
    _spinQueue = _spinQueue.then((_) async {
      if (!mounted || !_scrollController.hasClients || _isUserDragging) return;

      _momentumController.stop();

      final target = _scrollController.offset + (itemDelta * _itemExtent);

      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _startMomentumScroll(double velocity) async {
    if (!mounted || !_scrollController.hasClients) return;
    if (velocity.abs() < 40) return;

    _momentumController.stop();

    final simulation = FrictionSimulation(
      0.06,
      _scrollController.offset,
      -velocity,
    );

    _momentumController.value = _scrollController.offset;
    await _momentumController.animateWith(simulation);
  }

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController(
      initialScrollOffset: _centerIndex * _itemExtent,
    );
    _scrollController.addListener(_recenterIfNeeded);

    _momentumController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_momentumController.value);
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playIntroScroll();
    });
  }

  void _recenterIfNeeded() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final lowerBound = _itemExtent * 2000;
    final upperBound = _itemExtent * (_virtualItemCount - 2000);

    if (offset < lowerBound || offset > upperBound) {
      final itemPosition = offset / _itemExtent;
      final whole = itemPosition.floor();
      final fractional = itemPosition - whole;

      final normalizedWhole =
          ((whole % _garments.length) + _garments.length) % _garments.length;

      final newWhole = _centerIndex + normalizedWhole;
      final newOffset = (newWhole + fractional) * _itemExtent;

      _scrollController.jumpTo(newOffset);

      if (_momentumController.isAnimating) {
        _momentumController.value = newOffset;
      }
    }
  }

  Future<void> _playIntroScroll() async {
    if (_didPlayIntro) return;
    _didPlayIntro = true;

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted || !_scrollController.hasClients) return;

    final start = _scrollController.offset;
    final end = start + (_itemExtent * 8.0);

    unawaited(
      Future.delayed(
        Duration(milliseconds: (_introDuration.inMilliseconds * 0.48).round()),
        () {
          if (!mounted || _didRevealAuth) return;
          _didRevealAuth = true;
          widget.onIntroComplete?.call();
        },
      ),
    );

    await _scrollController.animateTo(
      end,
      duration: _introDuration,
      curve: Curves.easeOutCubic,
    );

    if (mounted && !_didRevealAuth) {
      _didRevealAuth = true;
      widget.onIntroComplete?.call();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_recenterIfNeeded);
    _scrollController.dispose();
    _momentumController.dispose();
    super.dispose();
  }

  Widget _buildRackBar() {
    return Positioned(
      top: 14,
      left: 0,
      right: 0,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.rail,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEdgeFade({required bool left}) {
    return IgnorePointer(
      child: Container(
        width: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              const Color(0xFFF7F5F1),
              const Color(0xFFF7F5F1).withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Stack(
        children: [
          _buildRackBar(),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                _momentumController.stop();
                _isUserDragging = true;
                _dragVelocity = 0.0;
                _lastDragTime = DateTime.now();
                _lastDragDx = details.globalPosition.dx;
              },
              onHorizontalDragUpdate: (details) {
                if (!_scrollController.hasClients) return;

                final nextOffset = _scrollController.offset - details.delta.dx;
                _scrollController.jumpTo(nextOffset);

                final now = DateTime.now();
                if (_lastDragTime != null && _lastDragDx != null) {
                  final dt =
                      now.difference(_lastDragTime!).inMilliseconds.clamp(1, 64);
                  final dx = details.globalPosition.dx - _lastDragDx!;
                  _dragVelocity = (dx / dt) * 1000;
                }

                _lastDragTime = now;
                _lastDragDx = details.globalPosition.dx;
              },
              onHorizontalDragEnd: (details) {
                _isUserDragging = false;

                final velocity = details.primaryVelocity ?? _dragVelocity;

                _lastDragTime = null;
                _lastDragDx = null;

                _startMomentumScroll(velocity);
              },
              onHorizontalDragCancel: () {
                _isUserDragging = false;
                _lastDragTime = null;
                _lastDragDx = null;
              },
              child: ClipRect(
                child: RepaintBoundary(
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _virtualItemCount,
                    itemExtent: _itemExtent,
                    cacheExtent: _itemExtent * 18,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemBuilder: (context, index) {
                      final garment = _garments[index % _garments.length];

                      return Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ProductRackGarment(
                            color: garment.color,
                            type: garment.type,
                            faded: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _buildEdgeFade(left: true),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _buildEdgeFade(left: false),
          ),
        ],
      ),
    );
  }
}

class _GarmentData {
  final Color color;
  final GarmentType type;
  final bool faded;

  const _GarmentData({
    required this.color,
    required this.type,
    this.faded = false,
  });
}

class ProductRackGarment extends StatelessWidget {
  final Color color;
  final GarmentType type;
  final bool faded;

  const ProductRackGarment({
    super.key,
    required this.color,
    required this.type,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    final hookColor = faded ? const Color(0xFFD7D3CD) : AppColors.connector;
    final hangerColor =
        faded ? const Color(0xFFD1CDC7) : const Color(0xFFA7A198);

    return SizedBox(
      width: 54,
      height: 106,
      child: Column(
        children: [
          Container(
            width: 2,
            height: 13,
            color: hookColor,
          ),
          Icon(
            Icons.checkroom_outlined,
            size: 26,
            color: hangerColor,
          ),
          Transform.translate(
            offset: const Offset(0, -3),
            child: Container(
              width: 2,
              height: 5,
              color: hookColor,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -7),
            child: SizedBox(
              width: 46,
              height: 56,
              child: CustomPaint(
                painter: GarmentPainter(
                  color: color,
                  faded: faded,
                  type: type,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GarmentPainter extends CustomPainter {
  final Color color;
  final bool faded;
  final GarmentType type;

  GarmentPainter({
    required this.color,
    required this.faded,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size, type);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(faded ? 0.01 : 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: faded
            ? [color.withOpacity(0.96), color]
            : [_lighten(color, 0.10), color],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, fillPaint);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(faded ? 0.06 : 0.18),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    final highlight = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 2, size.width - 16, 12),
      const Radius.circular(12),
    );
    canvas.drawRRect(highlight, highlightPaint);
  }

  Path _buildPath(Size size, GarmentType type) {
    switch (type) {
      case GarmentType.shirt:
        return _shirtPath(size);
      case GarmentType.hoodie:
        return _hoodiePath(size);
      case GarmentType.jacket:
        return _jacketPath(size);
    }
  }

  Path _shirtPath(Size size) {
    final w = size.width;
    final h = size.height;
    final p = Path();
    p.moveTo(w * 0.34, h * 0.12);
    p.lineTo(w * 0.22, h * 0.20);
    p.lineTo(w * 0.10, h * 0.34);
    p.quadraticBezierTo(w * 0.08, h * 0.40, w * 0.15, h * 0.47);
    p.lineTo(w * 0.22, h * 0.40);
    p.lineTo(w * 0.22, h * 0.84);
    p.quadraticBezierTo(w * 0.22, h * 0.96, w * 0.36, h * 0.96);
    p.lineTo(w * 0.64, h * 0.96);
    p.quadraticBezierTo(w * 0.78, h * 0.96, w * 0.78, h * 0.84);
    p.lineTo(w * 0.78, h * 0.40);
    p.lineTo(w * 0.85, h * 0.47);
    p.quadraticBezierTo(w * 0.92, h * 0.40, w * 0.90, h * 0.34);
    p.lineTo(w * 0.78, h * 0.20);
    p.lineTo(w * 0.66, h * 0.12);
    p.quadraticBezierTo(w * 0.58, h * 0.24, w * 0.50, h * 0.24);
    p.quadraticBezierTo(w * 0.42, h * 0.24, w * 0.34, h * 0.12);
    p.close();
    return p;
  }

  Path _hoodiePath(Size size) {
    final w = size.width;
    final h = size.height;
    final p = Path();
    p.moveTo(w * 0.28, h * 0.16);
    p.quadraticBezierTo(w * 0.35, h * 0.02, w * 0.50, h * 0.02);
    p.quadraticBezierTo(w * 0.65, h * 0.02, w * 0.72, h * 0.16);
    p.lineTo(w * 0.82, h * 0.26);
    p.lineTo(w * 0.92, h * 0.42);
    p.quadraticBezierTo(w * 0.94, h * 0.48, w * 0.87, h * 0.53);
    p.lineTo(w * 0.80, h * 0.48);
    p.lineTo(w * 0.78, h * 0.84);
    p.quadraticBezierTo(w * 0.78, h * 0.96, w * 0.66, h * 0.96);
    p.lineTo(w * 0.34, h * 0.96);
    p.quadraticBezierTo(w * 0.22, h * 0.96, w * 0.22, h * 0.84);
    p.lineTo(w * 0.20, h * 0.48);
    p.lineTo(w * 0.13, h * 0.53);
    p.quadraticBezierTo(w * 0.06, h * 0.48, w * 0.08, h * 0.42);
    p.lineTo(w * 0.18, h * 0.26);
    p.close();
    return p;
  }

  Path _jacketPath(Size size) {
    final w = size.width;
    final h = size.height;
    final p = Path();
    p.moveTo(w * 0.32, h * 0.10);
    p.lineTo(w * 0.18, h * 0.22);
    p.lineTo(w * 0.08, h * 0.42);
    p.quadraticBezierTo(w * 0.06, h * 0.48, w * 0.14, h * 0.52);
    p.lineTo(w * 0.20, h * 0.46);
    p.lineTo(w * 0.24, h * 0.90);
    p.quadraticBezierTo(w * 0.24, h * 0.96, w * 0.31, h * 0.96);
    p.lineTo(w * 0.69, h * 0.96);
    p.quadraticBezierTo(w * 0.76, h * 0.96, w * 0.76, h * 0.90);
    p.lineTo(w * 0.80, h * 0.46);
    p.lineTo(w * 0.86, h * 0.52);
    p.quadraticBezierTo(w * 0.94, h * 0.48, w * 0.92, h * 0.42);
    p.lineTo(w * 0.82, h * 0.22);
    p.lineTo(w * 0.68, h * 0.10);
    p.lineTo(w * 0.56, h * 0.28);
    p.lineTo(w * 0.52, h * 0.96);
    p.lineTo(w * 0.48, h * 0.96);
    p.lineTo(w * 0.44, h * 0.28);
    p.close();
    return p;
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(covariant GarmentPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.faded != faded ||
        oldDelegate.type != type;
  }
}

/// ---------- Main scaffold ----------
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int index = 1;
  late final PageController _pageController;

  late final List<Widget> pages = const [
    InventoryPage(),
    HomePage(),
    UploadPage(),
    WeatherPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          physics: const OnePageAtATimeScrollPhysics(),
          pageSnapping: true,
          onPageChanged: (value) {
            setState(() => index = value);
          },
          children: pages,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.72),
                      Colors.white.withOpacity(0.52),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final segmentWidth = constraints.maxWidth / 3;
                    const pillHorizontalInset = 7.0;
                    const pillTop = 5.0;
                    const pillHeight = 50.0;

                    return Stack(
                      children: [
                        Positioned(
                          left: 10,
                          right: 10,
                          top: 8,
                          child: IgnorePointer(
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.30),
                                    Colors.white.withOpacity(0.02),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          left: (index * segmentWidth) + pillHorizontalInset,
                          top: pillTop,
                          width: segmentWidth - (pillHorizontalInset * 2),
                          height: pillHeight,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.82),
                                    Colors.white.withOpacity(0.60),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.70),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.22),
                                    blurRadius: 8,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _NavItem(
                              label: "Inventory",
                              icon: Icons.inventory_2_rounded,
                              selected: index == 0,
                              onTap: () => _goToPage(0),
                            ),
                            _NavItem(
                              label: "Home",
                              icon: Icons.home_rounded,
                              selected: index == 1,
                              onTap: () => _goToPage(1),
                            ),
                            _NavItem(
                              label: "Upload",
                              icon: Icons.add_box_rounded,
                              selected: index == 2,
                              onTap: () => _goToPage(2),
                            ),
                          _NavItem(
                              label: "Weather",
                              icon: Icons.cloud_outlined,
                              selected: index == 3,
                              onTap: () => _goToPage(3),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHome = label == "Home";

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isHome ? 23 : 20,
                color: selected
                    ? AppColors.primary.withOpacity(0.95)
                    : Colors.black.withOpacity(0.38),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: isHome ? 13.5 : 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.primary.withOpacity(0.95)
                      : Colors.black.withOpacity(0.44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- Home ----------
enum ClosetCategory { tops, bottoms }

class ClothingOption {
  final String id;
  final String label;
  final ClosetCategory category;
  final Color color;

  const ClothingOption({
    required this.id,
    required this.label,
    required this.category,
    required this.color,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ClothingOption? selectedTop = _tops[0];
  ClothingOption? selectedBottom = _bottoms[0];

  late final PageController _closetPageController;
  int closetPageIndex = 0;

  static const List<ClothingOption> _tops = [
    ClothingOption(
      id: 'top_cream',
      label: 'Cream Tee',
      category: ClosetCategory.tops,
      color: Color(0xFFEADDCB),
    ),
    ClothingOption(
      id: 'top_teal',
      label: 'Teal Knit',
      category: ClosetCategory.tops,
      color: Color(0xFF0B7A69),
    ),
    ClothingOption(
      id: 'top_blue',
      label: 'Blue Shirt',
      category: ClosetCategory.tops,
      color: Color(0xFF6F93C9),
    ),
    ClothingOption(
      id: 'top_olive',
      label: 'Olive Top',
      category: ClosetCategory.tops,
      color: Color(0xFF7C8D63),
    ),
    ClothingOption(
      id: 'top_stone',
      label: 'Stone Knit',
      category: ClosetCategory.tops,
      color: Color(0xFFC9B6A0),
    ),
    ClothingOption(
      id: 'top_navy',
      label: 'Navy Hoodie',
      category: ClosetCategory.tops,
      color: Color(0xFF35527A),
    ),
  ];

  static const List<ClothingOption> _bottoms = [
    ClothingOption(
      id: 'bottom_black',
      label: 'Black Pants',
      category: ClosetCategory.bottoms,
      color: Color(0xFF3A3D43),
    ),
    ClothingOption(
      id: 'bottom_denim',
      label: 'Denim',
      category: ClosetCategory.bottoms,
      color: Color(0xFF5579A8),
    ),
    ClothingOption(
      id: 'bottom_stone',
      label: 'Stone Trousers',
      category: ClosetCategory.bottoms,
      color: Color(0xFFBFAE98),
    ),
    ClothingOption(
      id: 'bottom_sage',
      label: 'Sage Pants',
      category: ClosetCategory.bottoms,
      color: Color(0xFF8FA39A),
    ),
    ClothingOption(
      id: 'bottom_charcoal',
      label: 'Charcoal',
      category: ClosetCategory.bottoms,
      color: Color(0xFF50545B),
    ),
    ClothingOption(
      id: 'bottom_oat',
      label: 'Oat Trousers',
      category: ClosetCategory.bottoms,
      color: Color(0xFFD7CCBF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _closetPageController = PageController();
  }

  @override
  void dispose() {
    _closetPageController.dispose();
    super.dispose();
  }

  void _selectItem(ClothingOption option) {
    setState(() {
      switch (option.category) {
        case ClosetCategory.tops:
          selectedTop = option;
          break;
        case ClosetCategory.bottoms:
          selectedBottom = option;
          break;
      }
    });
  }

  bool _isOptionSelected(ClothingOption option) {
    switch (option.category) {
      case ClosetCategory.tops:
        return selectedTop?.id == option.id;
      case ClosetCategory.bottoms:
        return selectedBottom?.id == option.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appBackground(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 104),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.82),
                      Colors.white.withOpacity(0.70),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.86),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            flex: 11,
                            child: _buildHeroSection(),
                          ),
                          Expanded(
                            flex: 10,
                            child: _buildClosetPanel(),
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
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          _ModernCircleButton(
            icon: Icons.logout_rounded,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
          ),
          const SizedBox(width: 10),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.85)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 7),
                Text(
                  "18°C",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _ModernCircleButton(
            icon: Icons.person_outline_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            top: 60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B7A69).withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: 90,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF234E7E).withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 4,
            child: _ModernCircleButton(
              icon: Icons.bookmark_border_rounded,
              onTap: () {},
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 6),
              const Text(
                "Today's fit",
                style: TextStyle(
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Style your outfit from your closet",
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 18,
                      child: Container(
                        width: 180,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 26,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 1.02,
                      child: _AvatarBase(),
                    ),
                    if (selectedTop != null)
                      _AvatarTopOverlay(color: selectedTop!.color),
                    if (selectedBottom != null)
                      _AvatarBottomOverlay(color: selectedBottom!.color),
                    Positioned(
                      right: 18,
                      top: 40,
                      child: _ModernCircleButton(
                        icon: Icons.edit_outlined,
                        onTap: () {},
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey(
                    "${selectedTop?.id ?? 'none'}-${selectedBottom?.id ?? 'none'}",
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.68),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.82),
                    ),
                  ),
                  child: Text(
                    "${selectedTop?.label ?? ''} · ${selectedBottom?.label ?? ''}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClosetPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE8).withOpacity(0.94),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(34),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Closet",
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildSegmentedTabs(),
          const SizedBox(height: 14),
          Expanded(
            child: PageView(
              controller: _closetPageController,
              onPageChanged: (value) {
                setState(() {
                  closetPageIndex = value;
                });
              },
              children: [
                _buildClothingGrid(_tops),
                _buildClothingGrid(_bottoms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.88),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModernSegmentTab(
              label: "Tops",
              selected: closetPageIndex == 0,
              onTap: () {
                _closetPageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
          Expanded(
            child: _ModernSegmentTab(
              label: "Bottoms",
              selected: closetPageIndex == 1,
              onTap: () {
                _closetPageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClothingGrid(List<ClothingOption> items) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _isOptionSelected(item);

        return GestureDetector(
          onTap: () => _selectItem(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isSelected ? 0.95 : 0.72),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.90)
                    : Colors.white.withOpacity(0.85),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isSelected ? 0.08 : 0.04),
                  blurRadius: isSelected ? 18 : 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                item.color.withOpacity(0.18),
                                item.color.withOpacity(0.07),
                              ],
                            ),
                          ),
                        ),
                        _ClothingPreviewCard(
                          category: item.category,
                          color: item.color,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModernCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _ModernCircleButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? Colors.white.withOpacity(0.88)
              : Colors.white.withOpacity(0.70),
          border: Border.all(
            color: Colors.white.withOpacity(0.88),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ModernSegmentTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModernSegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F2128) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ClothingPreviewCard extends StatelessWidget {
  final ClosetCategory category;
  final Color color;

  const _ClothingPreviewCard({
    required this.category,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    switch (category) {
      case ClosetCategory.tops:
        return CustomPaint(
          size: const Size(54, 56),
          painter: _MiniTopPainter(color),
        );
      case ClosetCategory.bottoms:
        return CustomPaint(
          size: const Size(46, 60),
          painter: _MiniPantsPainter(color),
        );
    }
  }
}

/// ---------- Avatar ----------
class _AvatarBase extends StatelessWidget {
  _AvatarBase();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 390,
      child: CustomPaint(painter: _AvatarBasePainter()),
    );
  }
}

class _AvatarTopOverlay extends StatelessWidget {
  final Color color;

  const _AvatarTopOverlay({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 390,
      child: CustomPaint(painter: _AvatarTopPainter(color)),
    );
  }
}

class _AvatarBottomOverlay extends StatelessWidget {
  final Color color;

  const _AvatarBottomOverlay({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 390,
      child: CustomPaint(painter: _AvatarBottomPainter(color)),
    );
  }
}

class _AvatarBasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skin = Paint()..color = const Color(0xFFE2C3A6);
    final body = Paint()..color = const Color(0xFFF2EFE9);
    final hair = Paint()..color = const Color(0xFF41342D);
    final outline = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width / 2, 52), 34, skin);

    final hairPath = Path()
      ..moveTo(size.width / 2 - 34, 50)
      ..quadraticBezierTo(size.width / 2, 0, size.width / 2 + 34, 48)
      ..lineTo(size.width / 2 + 30, 36)
      ..quadraticBezierTo(size.width / 2, 10, size.width / 2 - 30, 36)
      ..close();
    canvas.drawPath(hairPath, hair);

    final neck = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, 92),
        width: 22,
        height: 24,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(neck, skin);

    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, 175),
        width: 112,
        height: 150,
      ),
      const Radius.circular(30),
    );
    canvas.drawRRect(torso, body);

    final leftArm = RRect.fromRectAndRadius(
      Rect.fromLTWH(34, 116, 30, 130),
      const Radius.circular(18),
    );
    final rightArm = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 64, 116, 30, 130),
      const Radius.circular(18),
    );
    canvas.drawRRect(leftArm, skin);
    canvas.drawRRect(rightArm, skin);

    final leftLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 42, 242, 30, 118),
      const Radius.circular(18),
    );
    final rightLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 + 12, 242, 30, 118),
      const Radius.circular(18),
    );
    canvas.drawRRect(leftLeg, skin);
    canvas.drawRRect(rightLeg, skin);

    final leftFoot = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 54, 344, 50, 18),
      const Radius.circular(10),
    );
    final rightFoot = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 + 6, 344, 50, 18),
      const Radius.circular(10),
    );
    canvas.drawRRect(leftFoot, skin);
    canvas.drawRRect(rightFoot, skin);

    canvas.drawRRect(torso, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AvatarTopPainter extends CustomPainter {
  final Color color;

  _AvatarTopPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(color, 0.10), color],
      ).createShader(Offset.zero & size);

    final topPath = Path()
      ..moveTo(size.width / 2 - 54, 110)
      ..lineTo(size.width / 2 - 88, 138)
      ..quadraticBezierTo(size.width / 2 - 100, 154, size.width / 2 - 86, 170)
      ..lineTo(size.width / 2 - 72, 162)
      ..lineTo(size.width / 2 - 60, 240)
      ..quadraticBezierTo(size.width / 2 - 58, 255, size.width / 2 - 42, 255)
      ..lineTo(size.width / 2 + 42, 255)
      ..quadraticBezierTo(size.width / 2 + 58, 255, size.width / 2 + 60, 240)
      ..lineTo(size.width / 2 + 72, 162)
      ..lineTo(size.width / 2 + 86, 170)
      ..quadraticBezierTo(size.width / 2 + 100, 154, size.width / 2 + 88, 138)
      ..lineTo(size.width / 2 + 54, 110)
      ..quadraticBezierTo(size.width / 2 + 34, 132, size.width / 2, 132)
      ..quadraticBezierTo(size.width / 2 - 34, 132, size.width / 2 - 54, 110)
      ..close();

    canvas.drawPath(topPath, fill);

    final collarPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final collar = Path()
      ..moveTo(size.width / 2 - 18, 114)
      ..quadraticBezierTo(size.width / 2, 132, size.width / 2 + 18, 114);
    canvas.drawPath(collar, collarPaint);
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _AvatarTopPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _AvatarBottomPainter extends CustomPainter {
  final Color color;

  _AvatarBottomPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(color, 0.08), color],
      ).createShader(Offset.zero & size);

    final leftLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 46, 242, 34, 118),
      const Radius.circular(18),
    );
    final rightLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 + 12, 242, 34, 118),
      const Radius.circular(18),
    );

    final waist = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, 240),
        width: 112,
        height: 28,
      ),
      const Radius.circular(12),
    );

    canvas.drawRRect(waist, fill);
    canvas.drawRRect(leftLeg, fill);
    canvas.drawRRect(rightLeg, fill);

    final seam = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 2.2;

    canvas.drawLine(
      Offset(size.width / 2, 252),
      Offset(size.width / 2, 358),
      seam,
    );
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _AvatarBottomPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// ---------- Mini clothing preview ----------
class _MiniTopPainter extends CustomPainter {
  final Color color;

  _MiniTopPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.10)
      ..lineTo(size.width * 0.10, size.height * 0.28)
      ..lineTo(size.width * 0.18, size.height * 0.42)
      ..lineTo(size.width * 0.25, size.height * 0.36)
      ..lineTo(size.width * 0.28, size.height * 0.92)
      ..lineTo(size.width * 0.72, size.height * 0.92)
      ..lineTo(size.width * 0.75, size.height * 0.36)
      ..lineTo(size.width * 0.82, size.height * 0.42)
      ..lineTo(size.width * 0.90, size.height * 0.28)
      ..lineTo(size.width * 0.74, size.height * 0.10)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.24,
        size.width * 0.50,
        size.height * 0.24,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.24,
        size.width * 0.26,
        size.height * 0.10,
      )
      ..close();

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _MiniTopPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MiniPantsPainter extends CustomPainter {
  final Color color;

  _MiniPantsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.06)
      ..lineTo(size.width * 0.82, size.height * 0.06)
      ..lineTo(size.width * 0.68, size.height * 0.96)
      ..lineTo(size.width * 0.52, size.height * 0.96)
      ..lineTo(size.width * 0.50, size.height * 0.52)
      ..lineTo(size.width * 0.48, size.height * 0.52)
      ..lineTo(size.width * 0.46, size.height * 0.96)
      ..lineTo(size.width * 0.30, size.height * 0.96)
      ..close();

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _MiniPantsPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// ---------- Shared buttons/cards ----------
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData leading;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(leading, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// ---------- Inventory ----------
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appBackground(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        children: const [
          Text(
            "Inventory",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Track your clothing usage and washing habits.",
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          SizedBox(height: 16),
          _InventoryTile(
            name: "White Button-Down",
            lastWorn: "Worn 3 days ago",
            lastWashed: "Washed 1 week ago",
          ),
          SizedBox(height: 10),
          _InventoryTile(
            name: "Charcoal Trousers",
            lastWorn: "Worn yesterday",
            lastWashed: "Washed 5 days ago",
          ),
          SizedBox(height: 10),
          _InventoryTile(
            name: "Denim Jacket",
            lastWorn: "Worn 1 week ago",
            lastWashed: "Washed 2 weeks ago",
          ),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final String name;
  final String lastWorn;
  final String lastWashed;

  const _InventoryTile({
    required this.name,
    required this.lastWorn,
    required this.lastWashed,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.checkroom_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lastWorn,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.local_laundry_service,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lastWashed,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  late Future<Map<String, dynamic>> weatherFuture;

  @override
  void initState() {
    super.initState();
    weatherFuture = fetchHamiltonWeather();
  }

  Future<Map<String, dynamic>> fetchHamiltonWeather() async {
    const latitude = 43.2557;
    const longitude = -79.8711;

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day'
      '&timezone=auto',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load weather');
    }

    final data = jsonDecode(response.body);
    return data['current'];
  }

  String weatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 95:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  IconData weatherIcon(int code, int isDay) {
    if (code == 0) {
      return isDay == 1 ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    } else if (code >= 1 && code <= 3) {
      return Icons.cloud_rounded;
    } else if (code == 45 || code == 48) {
      return Icons.foggy;
    } else if ((code >= 51 && code <= 55) || (code >= 61 && code <= 65) || (code >= 80 && code <= 82)) {
      return Icons.grain;
    } else if (code >= 71 && code <= 75) {
      return Icons.ac_unit;
    } else if (code == 95) {
      return Icons.thunderstorm;
    } else {
      return Icons.cloud_outlined;
    }
  }

  Future<void> refreshWeather() async {
    setState(() {
      weatherFuture = fetchHamiltonWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appBackground(),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: refreshWeather,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
            children: [
              const Text(
                "Weather",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Current weather in Hamilton",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>>(
                future: weatherFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _Card(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _Card(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 32,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Could not load weather.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  final current = snapshot.data!;
                  final temp = (current['temperature_2m'] as num).toDouble();
                  final humidity = current['relative_humidity_2m'];
                  final wind = (current['wind_speed_10m'] as num).toDouble();
                  final code = current['weather_code'] as int;
                  final isDay = current['is_day'] as int;
                  final time = current['time'] as String;

                  return _Card(
                    child: Column(
                      children: [
                        Icon(
                          weatherIcon(code, isDay),
                          size: 56,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Hamilton, ON",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${temp.toStringAsFixed(1)}°C',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weatherDescription(code),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _WeatherStat(
                              icon: Icons.water_drop_outlined,
                              label: 'Humidity',
                              value: '$humidity%',
                            ),
                            _WeatherStat(
                              icon: Icons.air,
                              label: 'Wind',
                              value: '${wind.toStringAsFixed(1)} km/h',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Updated: $time',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

/// ---------- Upload ----------
class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appBackground(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        children: [
          const Text(
            "Upload",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Demo view — camera + RFID intake will feed the digital closet.",
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Add a clothing item (demo)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "In the final system, the closet camera captures an image and stores metadata like type, color, and wear history.",
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                _PillButton(
                  label: "Simulate Camera Upload",
                  leading: Icons.camera_alt_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Demo: simulated camera upload"),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _PillButton(
                  label: "Simulate RFID Scan",
                  leading: Icons.nfc_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Demo: simulated RFID scan"),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}