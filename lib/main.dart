import 'dart:async';
import 'package:flutter/material.dart';

void main() {
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

  static const navBg = Color(0xFFF1ECE5);
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

/// ---------- Single auth page ----------
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isSignUp = false;
  bool showPassword = false;
  bool rememberMe = true;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void _goToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  void _switchToSignUp() {
    setState(() {
      isSignUp = true;
      showPassword = false;
    });
  }

  void _switchToLogin() {
    setState(() {
      isSignUp = false;
      showPassword = false;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  ClosetHeroHeader(
                    animateClothes: isSignUp,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 90,
                          child: Image.asset(
                            'assets/textyle_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.checkroom_rounded,
                                size: 54,
                                color: AppColors.primary,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 2),
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: isSignUp ? _buildSignUpCard() : _buildLoginCard(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18, top: 18),
                    child: Row(
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      key: const ValueKey('login-card'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(28),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Email Address",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: modernFieldDecoration(
              hint: "you@example.com",
              prefixIcon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Password",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: !showPassword,
            decoration: modernFieldDecoration(
              hint: "••••••••",
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
          ),
          const SizedBox(height: 10),
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
          const Spacer(),
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
    );
  }

  Widget _buildSignUpCard() {
    return Container(
      key: const ValueKey('signup-card'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(28),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Create Account",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Set up your account and start building your smart closet.",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            "Full Name",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: modernFieldDecoration(
              hint: "Enter your full name",
              prefixIcon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Email",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: modernFieldDecoration(
              hint: "Enter your email",
              prefixIcon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Password",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: !showPassword,
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
          ),
          const SizedBox(height: 10),
          const Text(
            "Use 8+ characters for a stronger password.",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _goToMainApp,
              child: const Text(
                "Create Account",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum GarmentType { shirt, hoodie, jacket }

class ClosetHeroHeader extends StatefulWidget {
  final bool animateClothes;

  const ClosetHeroHeader({
    super.key,
    this.animateClothes = false,
  });

  @override
  State<ClosetHeroHeader> createState() => _ClosetHeroHeaderState();
}

class _ClosetHeroHeaderState extends State<ClosetHeroHeader> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isAnimating = false;

  final List<List<_GarmentData>> _looks = const [
    [
      _GarmentData(
        color: Color(0xFFF2EFEB),
        type: GarmentType.shirt,
        faded: true,
      ),
      _GarmentData(
        color: Color(0xFF6C8C7A),
        type: GarmentType.shirt,
      ),
      _GarmentData(
        color: AppColors.primary,
        type: GarmentType.hoodie,
      ),
      _GarmentData(
        color: AppColors.secondary,
        type: GarmentType.jacket,
      ),
      _GarmentData(
        color: Color(0xFF9F8C7A),
        type: GarmentType.jacket,
      ),
      _GarmentData(
        color: Color(0xFFB7C6D9),
        type: GarmentType.shirt,
      ),
      _GarmentData(
        color: Color(0xFFF2EFEB),
        type: GarmentType.shirt,
        faded: true,
      ),
    ],
    [
      _GarmentData(
        color: Color(0xFFF2EFEB),
        type: GarmentType.shirt,
        faded: true,
      ),
      _GarmentData(
        color: AppColors.secondary,
        type: GarmentType.jacket,
      ),
      _GarmentData(
        color: AppColors.primary,
        type: GarmentType.hoodie,
      ),
      _GarmentData(
        color: Color(0xFF7A8F6C),
        type: GarmentType.shirt,
      ),
      _GarmentData(
        color: Color(0xFF8A6D5B),
        type: GarmentType.jacket,
      ),
      _GarmentData(
        color: Color(0xFFBBC8B4),
        type: GarmentType.shirt,
      ),
      _GarmentData(
        color: Color(0xFFF2EFEB),
        type: GarmentType.shirt,
        faded: true,
      ),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void didUpdateWidget(covariant ClosetHeroHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animateClothes != widget.animateClothes) {
      if (widget.animateClothes) {
        _animateToPage(1);
      } else {
        _animateToPage(0);
      }
    }
  }

  Future<void> _animateToPage(int targetPage) async {
    if (_isAnimating ||
        !_pageController.hasClients ||
        _currentPage == targetPage) {
      return;
    }

    _isAnimating = true;
    try {
      await _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
      _currentPage = targetPage;
    } finally {
      _isAnimating = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Widget _buildGarmentsPage(List<_GarmentData> garments) {
    const start = 6.0;
    const gap = 48.0;

    return SizedBox(
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < garments.length; i++)
            Positioned(
              top: 12,
              left: start + (gap * i),
              child: ProductRackGarment(
                color: garments[i].color,
                type: garments[i].type,
                faded: garments[i].faded,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Stack(
        children: [
          _buildRackBar(),
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _looks.length,
              itemBuilder: (context, index) {
                return _buildGarmentsPage(_looks[index]);
              },
            ),
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

/// ---------- Main app scaffold with bottom nav ----------
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int index = 1;

  final pages = const [
    InventoryPage(),
    HomePage(),
    UploadPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.navBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _NavItem(
                  label: "Inventory",
                  icon: Icons.inventory_2_rounded,
                  selected: index == 0,
                  onTap: () => setState(() => index = 0),
                ),
                _NavItem(
                  label: "Home",
                  icon: Icons.home_rounded,
                  selected: index == 1,
                  onTap: () => setState(() => index = 1),
                ),
                _NavItem(
                  label: "Upload",
                  icon: Icons.add_box_rounded,
                  selected: index == 2,
                  onTap: () => setState(() => index = 2),
                ),
              ],
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
    final bool showRaisedHome = isHome && selected;

    return Expanded(
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: isHome ? 92 : 78,
            height: showRaisedHome ? 58 : 44,
            decoration: BoxDecoration(
              color: selected
                  ? (showRaisedHome
                      ? const Color(0xFFF3EEE8)
                      : const Color(0xFFF4EEE8).withOpacity(0.75))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: showRaisedHome
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
              border: selected
                  ? Border.all(
                      color: Colors.white.withOpacity(0.45),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isHome ? 22 : 19,
                  color: selected
                      ? AppColors.primary.withOpacity(0.92)
                      : AppColors.textMuted.withOpacity(0.78),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isHome ? 13.5 : 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary.withOpacity(0.92)
                        : AppColors.textMuted.withOpacity(0.88),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------- Home ----------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appBackground(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  );
                },
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Closet Status: Not connected (demo)",
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Outfit",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        "Top:",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text("White Button-Down"),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        "Bottom:",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text("Charcoal Trousers"),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap “Present Outfit” to simulate the closet rotating + spotlighting.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: "Present Outfit",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Demo: presenting outfit")),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        label: "Pick Outfit",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Demo: picking outfit")),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PillButton(
            label: "Open Inventory",
            leading: Icons.checkroom_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Use bottom nav → Inventory")),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            title: "Side Intake (demo)",
            subtitle: "Hang clean clothes → system auto-sorts (later)",
            icon: Icons.subdirectory_arrow_right_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _QuickAction(
            title: "Calibrate (demo)",
            subtitle: "Assign hooks to shirt/pants zones (later)",
            icon: Icons.tune_rounded,
            onTap: () {},
          ),
        ],
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
            "Demo view — items will appear here after upload/scanning.",
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          SizedBox(height: 16),
          _InventoryTile(name: "White Button-Down", meta: "Last worn: 3 days ago"),
          SizedBox(height: 10),
          _InventoryTile(name: "Charcoal Trousers", meta: "Last washed: 1 week ago"),
          SizedBox(height: 10),
          _InventoryTile(name: "Denim Jacket", meta: "Weather suggestion: cool day"),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final String name;
  final String meta;

  const _InventoryTile({required this.name, required this.meta});

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
                const SizedBox(height: 4),
                Text(meta, style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
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
                  "In the final system, the closet camera captures an image and the software stores it with metadata (type, color, last worn/washed).",
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                _PillButton(
                  label: "Simulate Camera Upload",
                  leading: Icons.camera_alt_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Demo: simulated camera upload")),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _PillButton(
                  label: "Simulate RFID Scan",
                  leading: Icons.nfc_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Demo: simulated RFID scan")),
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

/// ---------- Small reusable widgets ----------
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
  final IconData? leading;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              Icon(leading, color: AppColors.primary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.64),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}