import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'models/clothing_item.dart';
import 'models/inventory_store.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack.toString());
  };

  runApp(
    ChangeNotifierProvider(
      create: (_) => InventoryStore(),
      child: const TextyleApp(),
    ),
  );
}

class TextyleApp extends StatelessWidget {
  const TextyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'textyle',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Inter',
      ),
      home: const AuthPage(),
    );
  }
}

/// ---------- Shared theme ----------
class AppColors {
  static const bg = Color(0xFFF8FBFF);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF7FAFD);

  static const primary = Color(0xFF0B7A69);
  static const primaryDark = Color(0xFF075F52);
  static const secondary = Color(0xFF234E7E);

  static const textDark = Color(0xFF1E1F22);
  static const textMuted = Color(0xFF7A7D82);
  static const hint = Color(0xFF9DA0A6);
  static const border = Color(0xFFDCE6F0);

  static const rail = Color(0xFF666666);
  static const connector = Color(0xFFB2ACA3);

  static const navBg = Colors.transparent;
  static const shadow = Color(0x14000000);

  static const fieldFill = Color(0xFFFFFFFF);
}

BoxDecoration appBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFFF8FBFF),
        Color(0xFFF2F7FC),
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
    isDense: true,
    hintStyle: TextStyle(
      color: AppColors.hint.withOpacity(0.88),
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: Colors.white.withOpacity(0.26),
    prefixIcon: Icon(
      prefixIcon,
      color: AppColors.textMuted.withOpacity(0.82),
      size: 18,
    ),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.92),
        width: 1.0,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.40),
        width: 1.2,
      ),
    ),
  );
}
/// ---------- Shared weather helpers ----------
const double _hamiltonLatitude = 43.2557;
const double _hamiltonLongitude = -79.8711;

Future<Map<String, dynamic>> fetchHamiltonWeather() async {
  final uri = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=$_hamiltonLatitude'
    '&longitude=$_hamiltonLongitude'
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day'
    '&timezone=auto',
  );

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception('Failed to load weather');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return Map<String, dynamic>.from(data['current'] as Map);
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
  } else if ((code >= 51 && code <= 55) ||
      (code >= 61 && code <= 65) ||
      (code >= 80 && code <= 82)) {
    return Icons.grain;
  } else if (code >= 71 && code <= 75) {
    return Icons.ac_unit;
  } else if (code == 95) {
    return Icons.thunderstorm;
  } else {
    return Icons.cloud_outlined;
  }
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
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                key: const ValueKey('login-card'),
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: Colors.white.withOpacity(0.58),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
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
                          cursorHeight: 15,
                          cursorColor: AppColors.primary,
                          onTap: () => _ensureFieldVisible(fieldContext),
                          decoration: modernFieldDecoration(
                            hint: "Enter your username",
                            prefixIcon: Icons.alternate_email_rounded,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
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
                          cursorHeight: 15,
                          cursorColor: AppColors.primary,
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
                                size: 18,
                                color: AppColors.textMuted.withOpacity(0.82),
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
                                fillColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primary;
                                  }
                                  return Colors.white.withOpacity(0.35);
                                }),
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.72),
                                  width: 1.0,
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
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSignUpCard() {
    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                key: const ValueKey('signup-card'),
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: Colors.white.withOpacity(0.58),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (fieldContext) {
                        return TextField(
                          textInputAction: TextInputAction.next,
                          cursorHeight: 15,
                          cursorColor: AppColors.primary,
                          onTap: () => _ensureFieldVisible(fieldContext),
                          decoration: modernFieldDecoration(
                            hint: "Enter your full name",
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Email",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (fieldContext) {
                        return TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          cursorHeight: 15,
                          cursorColor: AppColors.primary,
                          onTap: () => _ensureFieldVisible(fieldContext),
                          decoration: modernFieldDecoration(
                            hint: "Enter your email",
                            prefixIcon: Icons.email_outlined,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Username",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (fieldContext) {
                        return TextField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          cursorHeight: 15,
                          cursorColor: AppColors.primary,
                          onTap: () => _ensureFieldVisible(fieldContext),
                          decoration: modernFieldDecoration(
                            hint: "Choose a username",
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (fieldContext) {
                        return TextField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          textInputAction: TextInputAction.done,
                          cursorHeight: 15,
                          cursorColor: AppColors.primary,
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
                                size: 18,
                                color: AppColors.textMuted.withOpacity(0.82),
                              ),
                            ),
                          ),
                        );
                      },
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

Widget _buildAuthButton() {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 312),
      child: SizedBox(
        height: 30,
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          onPressed: _goToMainApp,
          child: Text(
            isSignUp ? "Create Account" : "Sign In",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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
                const SizedBox(height: 0),
                SizedBox(
                  height: 100,
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
                const SizedBox(height: 5),
                const Text(
                  "- more than just a walk-in -",
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
              const SizedBox(height: 14),
              _buildAuthButton(),
              const SizedBox(height: 10),
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
                  final isShort = constraints.maxHeight < 760;
                  final isVeryShort = constraints.maxHeight < 690;

                  final topGap = isVeryShort ? 6.0 : 14.0;
                  final rackGap = isVeryShort ? 6.0 : 10.0;
                  final brandGap = isVeryShort ? 10.0 : 14.0;
                  final cardGap = isVeryShort ? 10.0 : 16.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topGap),
                      ClosetHeroHeader(
                        key: _heroKey,
                        onIntroComplete: _handleRackIntroComplete,
                      ),
                      SizedBox(height: rackGap),
                      _buildBrandBlock(),
                      SizedBox(height: brandGap),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: keyboardInset + 12),
                          child: Column(
                            children: [
                              SizedBox(height: cardGap),
                              _buildAuthSection(),
                              const SizedBox(height: 12),
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
        height: 4,
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
              const Color(0xFFF8FBFF),
              const Color(0xFFF8FBFF).withOpacity(0.0),
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
    body: Stack(
      children: [
        Positioned.fill(
          child: SafeArea(
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
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: ClipRRect(
  borderRadius: BorderRadius.circular(32),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withOpacity(0.42),
        border: Border.all(
          color: Colors.white.withOpacity(0.80),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                      color: Colors.white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.88),
                        width: 1.0,
                      ),
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
      ],
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

class WardrobeItem {
  final String id;
  final String label;
  final ClosetCategory category;
  final Color color;
  final int lastWornDays;
  final int lastWashedDays;
  final String notes;
  final int wears;
  final String season;

  const WardrobeItem({
    required this.id,
    required this.label,
    required this.category,
    required this.color,
    required this.lastWornDays,
    required this.lastWashedDays,
    required this.notes,
    required this.wears,
    required this.season,
  });

  String get categoryLabel =>
      category == ClosetCategory.tops ? 'Top' : 'Bottom';

  String get lastWornLabel {
    if (lastWornDays == 0) return 'Worn today';
    if (lastWornDays == 1) return 'Worn yesterday';
    return 'Worn $lastWornDays days ago';
  }

  String get lastWashedLabel {
    if (lastWashedDays == 0) return 'Washed today';
    if (lastWashedDays == 1) return 'Washed yesterday';
    if (lastWashedDays == 7) return 'Washed 1 week ago';
    if (lastWashedDays == 14) return 'Washed 2 weeks ago';
    if (lastWashedDays % 7 == 0) {
      return 'Washed ${lastWashedDays ~/ 7} weeks ago';
    }
    return 'Washed $lastWashedDays days ago';
  }
}

const List<WardrobeItem> kDemoWardrobeItems = [
  WardrobeItem(
    id: 'bottom_black',
    label: 'Black Pants',
    category: ClosetCategory.bottoms,
    color: Color(0xFF3A3D43),
    lastWornDays: 1,
    lastWashedDays: 5,
    notes: 'Tailored black pants that ground most neutral outfits.',
    wears: 18,
    season: 'All Season',
  ),
  WardrobeItem(
    id: 'top_cream',
    label: 'Cream Tee',
    category: ClosetCategory.tops,
    color: Color(0xFFEADDCB),
    lastWornDays: 2,
    lastWashedDays: 6,
    notes: 'Soft cream tee that works with almost everything.',
    wears: 14,
    season: 'All Season',
  ),
  WardrobeItem(
    id: 'bottom_charcoal',
    label: 'Charcoal Trousers',
    category: ClosetCategory.bottoms,
    color: Color(0xFF50545B),
    lastWornDays: 3,
    lastWashedDays: 7,
    notes: 'Structured charcoal trousers for polished looks.',
    wears: 15,
    season: 'Fall / Winter',
  ),
  WardrobeItem(
    id: 'top_teal',
    label: 'Teal Knit',
    category: ClosetCategory.tops,
    color: Color(0xFF0B7A69),
    lastWornDays: 4,
    lastWashedDays: 8,
    notes: 'Textured knit top that adds a richer tone to the closet.',
    wears: 10,
    season: 'Fall / Winter',
  ),
  WardrobeItem(
    id: 'top_blue',
    label: 'Blue Shirt',
    category: ClosetCategory.tops,
    color: Color(0xFF6F93C9),
    lastWornDays: 7,
    lastWashedDays: 14,
    notes: 'Clean blue shirt for dressier or layered outfits.',
    wears: 11,
    season: 'Spring / Summer',
  ),
  WardrobeItem(
    id: 'bottom_denim',
    label: 'Denim',
    category: ClosetCategory.bottoms,
    color: Color(0xFF5579A8),
    lastWornDays: 8,
    lastWashedDays: 10,
    notes: 'Easy denim for casual everyday wear.',
    wears: 20,
    season: 'All Season',
  ),
  WardrobeItem(
    id: 'top_olive',
    label: 'Olive Top',
    category: ClosetCategory.tops,
    color: Color(0xFF7C8D63),
    lastWornDays: 9,
    lastWashedDays: 12,
    notes: 'Muted olive top that pairs well with dark bottoms.',
    wears: 7,
    season: 'Fall',
  ),
  WardrobeItem(
    id: 'bottom_sage',
    label: 'Sage Pants',
    category: ClosetCategory.bottoms,
    color: Color(0xFF8FA39A),
    lastWornDays: 10,
    lastWashedDays: 13,
    notes: 'Relaxed sage pants for softer looks and tonal outfits.',
    wears: 8,
    season: 'Spring',
  ),
  WardrobeItem(
    id: 'top_stone',
    label: 'Stone Knit',
    category: ClosetCategory.tops,
    color: Color(0xFFC9B6A0),
    lastWornDays: 11,
    lastWashedDays: 15,
    notes: 'Stone knit with a cozy, elevated casual feel.',
    wears: 9,
    season: 'Fall / Winter',
  ),
  WardrobeItem(
    id: 'bottom_oat',
    label: 'Oat Trousers',
    category: ClosetCategory.bottoms,
    color: Color(0xFFD7CCBF),
    lastWornDays: 12,
    lastWashedDays: 16,
    notes: 'Light oat trousers for softer neutral combinations.',
    wears: 6,
    season: 'Spring / Summer',
  ),
  WardrobeItem(
    id: 'top_navy',
    label: 'Navy Hoodie',
    category: ClosetCategory.tops,
    color: Color(0xFF35527A),
    lastWornDays: 13,
    lastWashedDays: 18,
    notes: 'A navy hoodie for relaxed layering and comfort.',
    wears: 16,
    season: 'Fall / Winter',
  ),
  WardrobeItem(
    id: 'bottom_stone',
    label: 'Stone Trousers',
    category: ClosetCategory.bottoms,
    color: Color(0xFFBFAE98),
    lastWornDays: 15,
    lastWashedDays: 20,
    notes: 'Stone trousers that lighten darker top combinations.',
    wears: 5,
    season: 'Spring / Summer',
  ),
];

List<WardrobeItem> get kDemoTops => kDemoWardrobeItems
    .where((item) => item.category == ClosetCategory.tops)
    .toList();

List<WardrobeItem> get kDemoBottoms => kDemoWardrobeItems
    .where((item) => item.category == ClosetCategory.bottoms)
    .toList();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late WardrobeItem? selectedTop;
  late WardrobeItem? selectedBottom;

  late final PageController _closetPageController;
  late Future<Map<String, dynamic>> _homeWeatherFuture;
  int closetPageIndex = 0;

  List<WardrobeItem> get _tops => kDemoTops;
  List<WardrobeItem> get _bottoms => kDemoBottoms;

  @override
  void initState() {
    super.initState();
    _closetPageController = PageController();
    _homeWeatherFuture = fetchHamiltonWeather();
    selectedTop = _tops.isNotEmpty ? _tops.first : null;
    selectedBottom = _bottoms.isNotEmpty ? _bottoms.first : null;
  }

  @override
  void dispose() {
    _closetPageController.dispose();
    super.dispose();
  }

  void _selectItem(WardrobeItem option) {
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

  bool _isOptionSelected(WardrobeItem option) {
    switch (option.category) {
      case ClosetCategory.tops:
        return selectedTop?.id == option.id;
      case ClosetCategory.bottoms:
        return selectedBottom?.id == option.id;
    }
  }

  void _openWeatherDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WeatherDetailPage(),
      ),
    );
  }

  Widget _buildWeatherChip() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _homeWeatherFuture,
      builder: (context, snapshot) {
        Widget leading;
        String label;

        if (snapshot.connectionState == ConnectionState.waiting) {
          leading = const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          );
          label = "Loading";
        } else if (snapshot.hasData) {
          final current = snapshot.data!;
          final temp = (current['temperature_2m'] as num).toDouble();
          final code = current['weather_code'] as int;
          final isDay = current['is_day'] as int;

          leading = Icon(
            weatherIcon(code, isDay),
            size: 16,
            color: AppColors.primary,
          );
          label = "${temp.toStringAsFixed(0)}°C";
        } else {
          leading = const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.primary,
          );
          label = "Weather";
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openWeatherDetails,
            borderRadius: BorderRadius.circular(24),
            child: Container(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading,
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Container(
    decoration: appBackground(),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
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
          _buildWeatherChip(),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
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

  Widget _buildClothingGrid(List<WardrobeItem> items) {
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
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
/// ---------- Inventory ----------
enum InventoryFilter {
  recentlyWorn,
  recentlyAdded,
  tops,
  bottoms,
  seasons,
  spring,
  summer,
  fall,
  winter,
  older,
  olderThanSixMonths,
  olderThanOneYear,
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _showSearch = false;
  bool _showSeasonSubfilters = false;
  bool _showOlderSubfilters = false;

  String _query = '';
  InventoryFilter _selectedFilter = InventoryFilter.recentlyWorn;

  List<WardrobeItem> get _filteredItems {
    final q = _query.trim().toLowerCase();
    List<WardrobeItem> items = [...kDemoWardrobeItems];

    switch (_selectedFilter) {
      case InventoryFilter.recentlyWorn:
        items.sort((a, b) => a.lastWornDays.compareTo(b.lastWornDays));
        break;
      case InventoryFilter.recentlyAdded:
        items = items.reversed.toList();
        break;
      case InventoryFilter.tops:
        items =
            items.where((item) => item.category == ClosetCategory.tops).toList();
        break;
      case InventoryFilter.bottoms:
        items = items
            .where((item) => item.category == ClosetCategory.bottoms)
            .toList();
        break;
      case InventoryFilter.seasons:
        items = items
            .where((item) =>
                item.season.toLowerCase().contains('spring') ||
                item.season.toLowerCase().contains('summer') ||
                item.season.toLowerCase().contains('fall') ||
                item.season.toLowerCase().contains('winter'))
            .toList();
        break;
      case InventoryFilter.spring:
        items = items
            .where((item) => item.season.toLowerCase().contains('spring'))
            .toList();
        break;
      case InventoryFilter.summer:
        items = items
            .where((item) => item.season.toLowerCase().contains('summer'))
            .toList();
        break;
      case InventoryFilter.fall:
        items = items
            .where((item) => item.season.toLowerCase().contains('fall'))
            .toList();
        break;
      case InventoryFilter.winter:
        items = items
            .where((item) => item.season.toLowerCase().contains('winter'))
            .toList();
        break;
      case InventoryFilter.older:
        items.sort((a, b) => b.lastWornDays.compareTo(a.lastWornDays));
        break;
      case InventoryFilter.olderThanSixMonths:
        items = items.where((item) => item.lastWornDays >= 180).toList();
        break;
      case InventoryFilter.olderThanOneYear:
        items = items.where((item) => item.lastWornDays >= 365).toList();
        break;
    }

    if (q.isEmpty) return items;

    return items.where((item) {
      return item.label.toLowerCase().contains(q) ||
          item.categoryLabel.toLowerCase().contains(q) ||
          item.season.toLowerCase().contains(q);
    }).toList();
  }

  bool _hasResultsFor(InventoryFilter filter) {
    final items = [...kDemoWardrobeItems];

    switch (filter) {
      case InventoryFilter.recentlyWorn:
      case InventoryFilter.recentlyAdded:
        return items.isNotEmpty;
      case InventoryFilter.tops:
        return items.any((item) => item.category == ClosetCategory.tops);
      case InventoryFilter.bottoms:
        return items.any((item) => item.category == ClosetCategory.bottoms);
      case InventoryFilter.seasons:
        return items.any(
          (item) =>
              item.season.toLowerCase().contains('spring') ||
              item.season.toLowerCase().contains('summer') ||
              item.season.toLowerCase().contains('fall') ||
              item.season.toLowerCase().contains('winter'),
        );
      case InventoryFilter.spring:
        return items.any(
          (item) => item.season.toLowerCase().contains('spring'),
        );
      case InventoryFilter.summer:
        return items.any(
          (item) => item.season.toLowerCase().contains('summer'),
        );
      case InventoryFilter.fall:
        return items.any(
          (item) => item.season.toLowerCase().contains('fall'),
        );
      case InventoryFilter.winter:
        return items.any(
          (item) => item.season.toLowerCase().contains('winter'),
        );
      case InventoryFilter.older:
        return items.any((item) => item.lastWornDays >= 180);
      case InventoryFilter.olderThanSixMonths:
        return items.any((item) => item.lastWornDays >= 180);
      case InventoryFilter.olderThanOneYear:
        return items.any((item) => item.lastWornDays >= 365);
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;

      if (!_showSearch) {
        _searchController.clear();
        _query = '';
        _searchFocusNode.unfocus();
      }
    });

    if (_showSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _selectFilter(InventoryFilter filter) {
    setState(() {
      _selectedFilter = filter;

      if (filter == InventoryFilter.seasons) {
        _showSeasonSubfilters = !_showSeasonSubfilters;
        _showOlderSubfilters = false;
      } else if (filter == InventoryFilter.older) {
        _showOlderSubfilters = !_showOlderSubfilters;
        _showSeasonSubfilters = false;
      } else {
        if (filter != InventoryFilter.spring &&
            filter != InventoryFilter.summer &&
            filter != InventoryFilter.fall &&
            filter != InventoryFilter.winter) {
          _showSeasonSubfilters = false;
        }

        if (filter != InventoryFilter.olderThanSixMonths &&
            filter != InventoryFilter.olderThanOneYear) {
          _showOlderSubfilters = false;
        }
      }
    });
  }

  String _filterLabel() {
    switch (_selectedFilter) {
      case InventoryFilter.recentlyWorn:
        return "Recently worn";
      case InventoryFilter.recentlyAdded:
        return "Recently added";
      case InventoryFilter.tops:
        return "Tops";
      case InventoryFilter.bottoms:
        return "Bottoms";
      case InventoryFilter.seasons:
        return "Seasons";
      case InventoryFilter.spring:
        return "Spring";
      case InventoryFilter.summer:
        return "Summer";
      case InventoryFilter.fall:
        return "Fall";
      case InventoryFilter.winter:
        return "Winter";
      case InventoryFilter.older:
        return "Older";
      case InventoryFilter.olderThanSixMonths:
        return "6+ months";
      case InventoryFilter.olderThanOneYear:
        return "1+ year";
    }
  }

  Widget _buildPrimaryFilterChips() {
    final primaryFilters = <_FilterChipData>[
      _FilterChipData(
        filter: InventoryFilter.recentlyWorn,
        label: "Recently worn",
        icon: Icons.history_rounded,
      ),
      _FilterChipData(
        filter: InventoryFilter.recentlyAdded,
        label: "Recently added",
        icon: Icons.auto_awesome_rounded,
      ),
      _FilterChipData(
        filter: InventoryFilter.tops,
        label: "Tops",
        icon: Icons.checkroom_outlined,
      ),
      _FilterChipData(
        filter: InventoryFilter.bottoms,
        label: "Bottoms",
        icon: Icons.accessibility_new_rounded,
      ),
      _FilterChipData(
        filter: InventoryFilter.seasons,
        label: "Seasons",
        icon: Icons.wb_sunny_outlined,
      ),
      _FilterChipData(
        filter: InventoryFilter.older,
        label: "Older",
        icon: Icons.schedule_rounded,
      ),
    ].where((chip) => _hasResultsFor(chip.filter)).toList();

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: primaryFilters.map((chip) {
          final selected = chip.filter == InventoryFilter.seasons
              ? _showSeasonSubfilters ||
                  _selectedFilter == InventoryFilter.spring ||
                  _selectedFilter == InventoryFilter.summer ||
                  _selectedFilter == InventoryFilter.fall ||
                  _selectedFilter == InventoryFilter.winter
              : chip.filter == InventoryFilter.older
                  ? _showOlderSubfilters ||
                      _selectedFilter == InventoryFilter.olderThanSixMonths ||
                      _selectedFilter == InventoryFilter.olderThanOneYear
                  : _selectedFilter == chip.filter;

          return _InventoryFilterChip(
            label: chip.label,
            icon: chip.icon,
            selected: selected,
            onTap: () => _selectFilter(chip.filter),
            trailingIcon: chip.filter == InventoryFilter.seasons ||
                    chip.filter == InventoryFilter.older
                ? (selected
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded)
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeasonSubfilters() {
    final seasonFilters = <_FilterChipData>[
      _FilterChipData(
        filter: InventoryFilter.spring,
        label: "Spring",
      ),
      _FilterChipData(
        filter: InventoryFilter.summer,
        label: "Summer",
      ),
      _FilterChipData(
        filter: InventoryFilter.fall,
        label: "Fall",
      ),
      _FilterChipData(
        filter: InventoryFilter.winter,
        label: "Winter",
      ),
    ].where((chip) => _hasResultsFor(chip.filter)).toList();

    if (!_showSeasonSubfilters || seasonFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: seasonFilters.map((chip) {
            return _InventoryFilterChip(
              label: chip.label,
              selected: _selectedFilter == chip.filter,
              compact: true,
              onTap: () => _selectFilter(chip.filter),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOlderSubfilters() {
    final olderFilters = <_FilterChipData>[
      _FilterChipData(
        filter: InventoryFilter.olderThanSixMonths,
        label: "6+ months",
      ),
      _FilterChipData(
        filter: InventoryFilter.olderThanOneYear,
        label: "1+ year",
      ),
    ].where((chip) => _hasResultsFor(chip.filter)).toList();

    if (!_showOlderSubfilters || olderFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: olderFilters.map((chip) {
            return _InventoryFilterChip(
              label: chip.label,
              selected: _selectedFilter == chip.filter,
              compact: true,
              onTap: () => _selectFilter(chip.filter),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Container(
      decoration: appBackground(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Inventory",
                            style: TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.9,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Wear, wash, and closet history",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _ModernCircleButton(
                      icon: _showSearch
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      onTap: _toggleSearch,
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showSearch
                    ? Padding(
                        key: const ValueKey('inventory-search-open'),
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                            });
                          },
                          decoration: modernFieldDecoration(
                            hint: "Search inventory",
                            prefixIcon: Icons.search_rounded,
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('inventory-search-closed'),
                        height: 6,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Column(
                  children: [
                    _buildPrimaryFilterChips(),
                    _buildSeasonSubfilters(),
                    _buildOlderSubfilters(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                child: Row(
                  children: [
                    Text(
                      _filterLabel(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${items.length} items",
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          "No items found",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 92),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _InventoryRowCard(item: items[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipData {
  final InventoryFilter filter;
  final String label;
  final IconData? icon;

  const _FilterChipData({
    required this.filter,
    required this.label,
    this.icon,
  });
}

class _InventoryFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _InventoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withOpacity(0.82)
                  : Colors.white.withOpacity(0.42),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? Colors.white.withOpacity(0.96)
                    : Colors.white.withOpacity(0.72),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: compact ? 14 : 16,
                    color: selected ? AppColors.textDark : AppColors.textMuted,
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 5),
                  Icon(
                    trailingIcon,
                    size: 16,
                    color: selected ? AppColors.textDark : AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryRowCard extends StatelessWidget {
  final WardrobeItem item;

  const _InventoryRowCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => _InventoryDetailSheet(item: item),
          );
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.90),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -2),
                        child: _ClothingPreviewCard(
                          category: item.category,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InventoryMetaLine(
                      icon: Icons.access_time_rounded,
                      text: item.lastWornLabel,
                    ),
                    const SizedBox(height: 4),
                    _InventoryMetaLine(
                      icon: Icons.local_laundry_service_outlined,
                      text: item.lastWashedLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.black.withOpacity(0.22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InventoryMetaLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.black.withOpacity(0.34),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.1,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InventoryMetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.black.withOpacity(0.40),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryDetailSheet extends StatelessWidget {
  final WardrobeItem item;

  const _InventoryDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1ECE5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  item.color.withOpacity(0.18),
                                  item.color.withOpacity(0.05),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.categoryLabel} · ${item.season}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _InventoryInfoCard(
                      icon: Icons.watch_later_outlined,
                      label: 'Last worn',
                      value: item.lastWornLabel.replaceFirst('Worn ', ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InventoryInfoCard(
                      icon: Icons.local_laundry_service_outlined,
                      label: 'Last washed',
                      value: item.lastWashedLabel.replaceFirst('Washed ', ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InventoryInfoCard(
                      icon: Icons.repeat_rounded,
                      label: 'Total wears',
                      value: '${item.wears}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InventoryInfoCard(
                      icon: Icons.sell_outlined,
                      label: 'Category',
                      value: item.categoryLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
                child: Text(
                  item.notes,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InventoryInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.92),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF6F3EE),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// ---------- Weather detail page ----------
class WeatherDetailPage extends StatefulWidget {
  const WeatherDetailPage({super.key});

  @override
  State<WeatherDetailPage> createState() => _WeatherDetailPageState();
}

class _WeatherDetailPageState extends State<WeatherDetailPage> {
  late Future<Map<String, dynamic>> weatherFuture;

  @override
  void initState() {
    super.initState();
    weatherFuture = fetchHamiltonWeather();
  }

  Future<void> refreshWeather() async {
    final refreshed = fetchHamiltonWeather();
    setState(() {
      weatherFuture = refreshed;
    });
    await refreshed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: refreshWeather,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              children: [
                Row(
                  children: [
                    _ModernCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Weather",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
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
class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isPicking = true;
      });

      final file = await _picker.pickImage(
        source: source,
        imageQuality: 88,
      );

      if (!mounted) return;

      if (file != null) {
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _savePickedItem() async {
    if (_selectedImage == null) return;

    final ClothingType? selectedType =
        await showModalBottomSheet<ClothingType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'What type of item is this?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _TypeChoiceTile(
                  label: 'Top',
                  icon: Icons.checkroom_rounded,
                  onTap: () => Navigator.pop(context, ClothingType.top),
                ),
                const SizedBox(height: 10),
                _TypeChoiceTile(
                  label: 'Bottom',
                  icon: Icons.dry_cleaning_rounded,
                  onTap: () => Navigator.pop(context, ClothingType.bottom),
                ),
                const SizedBox(height: 10),
                _TypeChoiceTile(
                  label: 'Accessory',
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => Navigator.pop(context, ClothingType.accessory),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedType == null) return;

    final fileName = _selectedImage!.name;
    final dotIndex = fileName.lastIndexOf('.');
    final displayName =
        dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;

    context.read<InventoryStore>().addItem(
          ClothingItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: selectedType,
            name: displayName.isEmpty ? 'New Item' : displayName,
            colorLabel: 'Uploaded',
            originalImagePath: _selectedImage!.path,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item added to inventory'),
        duration: Duration(milliseconds: 900),
      ),
    );

    setState(() {
      _selectedImage = null;
    });
  }

@override
Widget build(BuildContext context) {
  return Container(
    decoration: appBackground(),
    child: Stack(
      children: [
        const _UploadAmbientBackground(),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ModernCircleButton(
                      icon: Icons.photo_library_outlined,
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                    const Spacer(),
                    _ModernCircleButton(
                      icon: Icons.camera_alt_outlined,
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Upload',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add a real clothing image from your gallery or camera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.86),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F1EA),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.90),
                              ),
                            ),
                            child: _selectedImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 88,
                                        height: 88,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.78),
                                        ),
                                        child: _isPicking
                                            ? const Padding(
                                                padding: EdgeInsets.all(28),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.add_photo_alternate_outlined,
                                                size: 38,
                                                color: AppColors.primary,
                                              ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No image selected yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Pick a clothing photo to add it to your inventory',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.network(
                                      _selectedImage!.path,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) {
                                        return Container(
                                          color: const Color(0xFFF2EEE8),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            size: 42,
                                            color: AppColors.textMuted,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: _selectedImage == null
                                ? null
                                : _savePickedItem,
                            child: Text(
                              _selectedImage == null
                                  ? 'Choose an image first'
                                  : 'Add to Inventory',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _UploadQuickActionCard(
                                icon: Icons.photo_library_outlined,
                                title: 'Gallery',
                                subtitle: 'Pick a clothing photo',
                                onTap: () => _pickImage(ImageSource.gallery),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _UploadQuickActionCard(
                                icon: Icons.camera_alt_outlined,
                                title: 'Camera',
                                subtitle: 'Take a clothing photo',
                                onTap: () => _pickImage(ImageSource.camera),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}

class _TypeChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeChoiceTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F2EC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientShape extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double radius;

  const _AmbientShape({
    required this.width,
    required this.height,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _UploadAmbientBackground extends StatelessWidget {
  const _UploadAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: 220,
            child: _AmbientShape(
              width: 170,
              height: 260,
              color: const Color(0xFF0B7A69).withOpacity(0.05),
              radius: 90,
            ),
          ),
          Positioned(
            right: -10,
            top: 150,
            child: _AmbientShape(
              width: 150,
              height: 220,
              color: const Color(0xFF234E7E).withOpacity(0.05),
              radius: 70,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _UploadQuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.72),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
