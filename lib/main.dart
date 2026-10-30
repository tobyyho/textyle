import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'models/clothing_item.dart';
import 'models/inventory_store.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack.toString());
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryStore()),
        ChangeNotifierProvider(create: (_) => AvatarSettings()),
      ],
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
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          background: AppColors.bg,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Inter',
              bodyColor: AppColors.textDark,
              displayColor: AppColors.textDark,
            ),
      ),
      home: const AuthPage(),
    );
  }
}

/// ---------- Shared theme ----------
class AppColors {
  static const bg = Color(0xFFF4F7FA);
  static const bgSoft = Color(0xFFF8FBFF);
  static const surface = Colors.white;

  static const primary = Color(0xFF0A8B79);

  static const textDark = Color(0xFF1D2228);
  static const textMuted = Color(0xFF7D838A);
  static const hint = Color(0xFF9BA0A6);
  static const border = Color(0xFFDCE6F0);

  static const rail = Color(0xFF666666);
  static const connector = Color(0xFFB2ACA3);
  static const shadow = Color(0x14000000);

}

enum AvatarBodyType {
  male,
  female,
}

class AvatarSettings extends ChangeNotifier {
  AvatarBodyType _bodyType = AvatarBodyType.male;

  AvatarBodyType get bodyType => _bodyType;

  String get avatarAsset {
    switch (_bodyType) {
      case AvatarBodyType.male:
        return 'assets/avatar/male.glb';
      case AvatarBodyType.female:
        return 'assets/avatar/female.glb';
    }
  }

  void setBodyType(AvatarBodyType type) {
    if (_bodyType == type) return;
    _bodyType = type;
    notifyListeners();
  }
}

BoxDecoration appBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.bgSoft,
        AppColors.bg,
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

Future<Map<String, dynamic>> fetchHamiltonWeatherForecast() async {
  final uri = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=$_hamiltonLatitude'
    '&longitude=$_hamiltonLongitude'
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day'
    '&hourly=temperature_2m,precipitation_probability,weather_code,wind_speed_10m'
    '&forecast_days=2'
    '&timezone=auto',
  );

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception('Failed to load forecast');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return data;
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
  bool _isSigningIn = false;
  bool _signedIn = false;
  AvatarBodyType signUpBodyType = AvatarBodyType.male;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();


  final GlobalKey<_ClosetHeroHeaderState> _heroKey =
      GlobalKey<_ClosetHeroHeaderState>();

  void _handleRackIntroComplete() {
    if (!mounted || showAuthContent) return;
    setState(() {
      showAuthContent = true;
    });
  }

  Future<void> _goToMainApp() async {
    if (_isSigningIn) return;

    FocusScope.of(context).unfocus();

    if (isSignUp) {
      context.read<AvatarSettings>().setBodyType(signUpBodyType);
    }

    setState(() {
      _isSigningIn = true;
    });

    // Keep the existing clothing-rack loading animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _heroKey.currentState?.startContinuousLoadingScroll();
      }
    });

    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    // Build exactly one screen: never mount Home beneath the auth page.
    setState(() {
      _signedIn = true;
    });
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
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                    const SizedBox(height: 16),
                    const Text(
                      "Choose your avatar",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.34),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.78),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SignUpAvatarChoice(
                              label: 'Male',
                              icon: Icons.male_rounded,
                              selected:
                                  signUpBodyType == AvatarBodyType.male,
                              onTap: () {
                                setState(() {
                                  signUpBodyType = AvatarBodyType.male;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _SignUpAvatarChoice(
                              label: 'Female',
                              icon: Icons.female_rounded,
                              selected:
                                  signUpBodyType == AvatarBodyType.female,
                              onTap: () {
                                setState(() {
                                  signUpBodyType = AvatarBodyType.female;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This chooses which fitted clothing collection the app uses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
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
          onPressed: _isSigningIn ? null : _goToMainApp,
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
      opacity: showAuthContent && !_isSigningIn ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        offset: showAuthContent && !_isSigningIn
            ? Offset.zero
            : const Offset(0, 0.05),
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
    final visible = showAuthContent && !_isSigningIn;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      opacity: visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInCubic,
        offset: _isSigningIn
            ? const Offset(0, 1.55)
            : (showAuthContent ? Offset.zero : const Offset(0, 0.05)),
        child: IgnorePointer(
          ignoring: !visible,
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

  Widget _buildLoadingContent() {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          const Text(
            'preparing your wardrobe',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0x1A0A8B79),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
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
    if (_signedIn) {
      return const MainScaffold();
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Scaffold(
                    resizeToAvoidBottomInset: true,
                    body: Container(
                      decoration: appBackground(),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isVeryShort = constraints.maxHeight < 690;

                              final topGap = isVeryShort ? 6.0 : 14.0;
                              final rackGap = isVeryShort ? 6.0 : 10.0;
                              final brandGap = isVeryShort ? 10.0 : 14.0;
                              final cardGap = isVeryShort ? 10.0 : 16.0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: topGap),

                                  // SAME rack before, during, and after pressing
                                  // Sign In. It is never rebuilt as a different
                                  // loading-rack widget.
                                  ClosetHeroHeader(
                                    key: _heroKey,
                                    onIntroComplete:
                                        _handleRackIntroComplete,
                                  ),

                                  SizedBox(height: rackGap),

                                  _buildBrandBlock(),

                                  SizedBox(height: brandGap),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      physics:
                                          const BouncingScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        bottom: keyboardInset + 12,
                                      ),
                                      child: Column(
                                        children: [
                                          SizedBox(height: cardGap),

                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 280,
                                            ),
                                            switchInCurve:
                                                Curves.easeOutCubic,
                                            switchOutCurve:
                                                Curves.easeInCubic,
                                            child: _isSigningIn
                                                ? _buildLoadingContent()
                                                : _buildAuthSection(),
                                          ),

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
          ),
        ),
      ],
    );
  }
}


class _SignUpAvatarChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SignUpAvatarChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white.withOpacity(0.92) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
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
  static const int _virtualItemCount = 6000;
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

  void startContinuousLoadingScroll() {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) startContinuousLoadingScroll();
      });
      return;
    }

    _momentumController.stop();
    _isUserDragging = false;

    // One long linear movement. Since the loading state lasts ~5 seconds,
    // the user never sees an animation restart or seam.
    final target = _scrollController.offset + (_itemExtent * 300.0);

    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(seconds: 45),
        curve: Curves.linear,
      ),
    );
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
    final lowerBound = _itemExtent * 500;
    final upperBound = _itemExtent * (_virtualItemCount - 500);

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
      top: 54,
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
      height: 172,
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
                    cacheExtent: _itemExtent * 4,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemBuilder: (context, index) {
                      final garment = _garments[index % _garments.length];

                      return Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 52),
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

  const _GarmentData({
    required this.color,
    required this.type,
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
              physics: const NeverScrollableScrollPhysics(),
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
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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

enum ClosetCategory {
  tops,
  bottoms,
}

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
  final String? overlayAsset;
  final String? modelFileName;
  final bool availableForMale;
  final bool availableForFemale;

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
    this.overlayAsset,
    this.modelFileName,
    this.availableForMale = true,
    this.availableForFemale = true,
  });


  bool isAvailableFor(AvatarBodyType bodyType) {
    return bodyType == AvatarBodyType.female
        ? availableForFemale
        : availableForMale;
  }

  String? modelAssetFor(AvatarBodyType bodyType) {
    final fileName = modelFileName;
    if (fileName == null || fileName.isEmpty) return null;

    final bodyFolder =
        bodyType == AvatarBodyType.female ? 'female' : 'male';
    final categoryFolder =
        category == ClosetCategory.tops ? 'tops' : 'bottoms';

    return 'assets/clothing/$bodyFolder/$categoryFolder/$fileName';
  }

  String get categoryLabel {
    switch (category) {
      case ClosetCategory.tops:
        return 'Tops';
      case ClosetCategory.bottoms:
        return 'Bottoms';
    }
  }
  String get lastWornLabel {
  if (lastWornDays == 0) return 'Worn today';
  if (lastWornDays == 1) return 'Worn yesterday';
  if (lastWornDays < 7) return 'Worn $lastWornDays days ago';

  final weeks = (lastWornDays / 7).round();
  if (weeks == 1) return 'Worn 1 week ago';
  if (lastWornDays < 30) return 'Worn $weeks weeks ago';

  final months = (lastWornDays / 30).round();
  if (months == 1) return 'Worn 1 month ago';
  return 'Worn $months months ago';
}

String get lastWashedLabel {
  if (lastWashedDays == 0) return 'Washed today';
  if (lastWashedDays == 1) return 'Washed yesterday';
  if (lastWashedDays < 7) return 'Washed $lastWashedDays days ago';

  final weeks = (lastWashedDays / 7).round();
  if (weeks == 1) return 'Washed 1 week ago';
  if (lastWashedDays < 30) return 'Washed $weeks weeks ago';

  final months = (lastWashedDays / 30).round();
  if (months == 1) return 'Washed 1 month ago';
  return 'Washed $months months ago';
}
}

const List<WardrobeItem> kDemoWardrobeItems = [
  // MALE TOPS
  WardrobeItem(
    id: 'male_top_zipper_hoodie',
    label: 'Zipper Hoodie',
    category: ClosetCategory.tops,
    color: Color(0xFF234E7E),
    lastWornDays: 0,
    lastWashedDays: 4,
    notes: 'Zipper hoodie.',
    wears: 3,
    season: 'All Season',
    modelFileName: 'zipperhoodiem.glb',
    availableForMale: true,
    availableForFemale: false,
  ),
  WardrobeItem(
    id: 'male_top_tshirt',
    label: 'T-Shirt',
    category: ClosetCategory.tops,
    color: Color(0xFFEADDCB),
    lastWornDays: 1,
    lastWashedDays: 5,
    notes: 'T-shirt.',
    wears: 4,
    season: 'All Season',
    modelFileName: 'tshirtm.glb',
    availableForMale: true,
    availableForFemale: false,
  ),
  WardrobeItem(
    id: 'male_top_sweater',
    label: 'Sweater',
    category: ClosetCategory.tops,
    color: Color(0xFF9F8C7A),
    lastWornDays: 3,
    lastWashedDays: 7,
    notes: 'Sweater without a hood.',
    wears: 6,
    season: 'All Season',
    modelFileName: 'sweaterm.glb',
    availableForMale: true,
    availableForFemale: false,
  ),
  WardrobeItem(
    id: 'male_top_relaxed_tshirt',
    label: 'Relaxed T-Shirt',
    category: ClosetCategory.tops,
    color: Color(0xFF6F95D1),
    lastWornDays: 4,
    lastWashedDays: 8,
    notes: 'Relaxed fit T-shirt.',
    wears: 7,
    season: 'All Season',
    modelFileName: 'relaxedtshirtm.glb',
    availableForMale: true,
    availableForFemale: false,
  ),
  WardrobeItem(
    id: 'male_top_pullover',
    label: 'Pullover',
    category: ClosetCategory.tops,
    color: Color(0xFF0B7A69),
    lastWornDays: 2,
    lastWashedDays: 6,
    notes: 'Pullover.',
    wears: 5,
    season: 'All Season',
    modelFileName: 'pulloverm.glb',
    availableForMale: true,
    availableForFemale: false,
  ),

  // MALE BOTTOMS
  WardrobeItem(
    id: 'male_bottom_jeans',
    label: 'Jeans',
    category: ClosetCategory.bottoms,
    color: Color(0xFF5579A8),
    lastWornDays: 5,
    lastWashedDays: 9,
    notes: 'Jeans.',
    wears: 8,
    season: 'All Season',
    modelFileName: 'jeans.glb',
    availableForMale: true,
    availableForFemale: false,
  ),
  WardrobeItem(
    id: 'male_bottom_black_pants',
    label: 'Black Pants',
    category: ClosetCategory.bottoms,
    color: Color(0xFF2E3035),
    lastWornDays: 6,
    lastWashedDays: 10,
    notes: 'Black pants.',
    wears: 9,
    season: 'All Season',
    modelFileName: 'blackpants.glb',
    availableForMale: true,
    availableForFemale: false,
  ),

  // FEMALE TOPS
  WardrobeItem(
    id: 'female_top_zipper_hoodie',
    label: 'Zipper Hoodie',
    category: ClosetCategory.tops,
    color: Color(0xFF234E7E),
    lastWornDays: 0,
    lastWashedDays: 4,
    notes: 'Zipper hoodie.',
    wears: 3,
    season: 'All Season',
    modelFileName: 'zipperhoodief.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_top_tshirt',
    label: 'T-Shirt',
    category: ClosetCategory.tops,
    color: Color(0xFFEADDCB),
    lastWornDays: 1,
    lastWashedDays: 5,
    notes: 'T-shirt.',
    wears: 4,
    season: 'All Season',
    modelFileName: 'tshirtf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_top_sweater',
    label: 'Sweater',
    category: ClosetCategory.tops,
    color: Color(0xFF6C8C7A),
    lastWornDays: 2,
    lastWashedDays: 6,
    notes: 'Sweater without a hood.',
    wears: 5,
    season: 'All Season',
    modelFileName: 'sweaternohoodief.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_top_relaxed_tshirt',
    label: 'Relaxed T-Shirt',
    category: ClosetCategory.tops,
    color: Color(0xFF6F95D1),
    lastWornDays: 3,
    lastWashedDays: 7,
    notes: 'Relaxed fit T-shirt.',
    wears: 6,
    season: 'All Season',
    modelFileName: 'relaxedtshirtf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_top_hoodie',
    label: 'Hoodie',
    category: ClosetCategory.tops,
    color: Color(0xFF9F8C7A),
    lastWornDays: 4,
    lastWashedDays: 8,
    notes: 'Pullover hoodie.',
    wears: 7,
    season: 'All Season',
    modelFileName: 'hoodief.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_top_cropped_shirt',
    label: 'Cropped Shirt',
    category: ClosetCategory.tops,
    color: Color(0xFFF4F1EA),
    lastWornDays: 5,
    lastWashedDays: 9,
    notes: 'Cropped shirt.',
    wears: 8,
    season: 'All Season',
    modelFileName: 'croppedshirtf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),

  // FEMALE BOTTOMS
  WardrobeItem(
    id: 'female_bottom_tennis_skirt',
    label: 'Tennis Skirt',
    category: ClosetCategory.bottoms,
    color: Color(0xFFF4F1EA),
    lastWornDays: 0,
    lastWashedDays: 3,
    notes: 'Tennis skirt.',
    wears: 5,
    season: 'All Season',
    modelFileName: 'tennisskirtf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_bottom_sweats',
    label: 'Sweatpants',
    category: ClosetCategory.bottoms,
    color: Color(0xFF545A61),
    lastWornDays: 1,
    lastWashedDays: 4,
    notes: 'Sweatpants.',
    wears: 6,
    season: 'All Season',
    modelFileName: 'sweatsf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_bottom_skinny_jeans',
    label: 'Skinny Jeans',
    category: ClosetCategory.bottoms,
    color: Color(0xFF5579A8),
    lastWornDays: 2,
    lastWashedDays: 5,
    notes: 'Skinny jeans.',
    wears: 7,
    season: 'All Season',
    modelFileName: 'skinnyjeansf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
  WardrobeItem(
    id: 'female_bottom_pencil_pleated_skirt',
    label: 'Pencil Pleated Skirt',
    category: ClosetCategory.bottoms,
    color: Color(0xFF6C8C7A),
    lastWornDays: 3,
    lastWashedDays: 6,
    notes: 'Pencil pleated skirt.',
    wears: 8,
    season: 'All Season',
    modelFileName: 'pencilpleatedskirtf.glb',
    availableForMale: false,
    availableForFemale: true,
  ),
];

List<WardrobeItem> wardrobeItemsFor(AvatarBodyType bodyType) {
  return kDemoWardrobeItems
      .where((item) => item.isAvailableFor(bodyType))
      .toList(growable: false);
}

class SavedOutfit {
  final WardrobeItem top;
  final WardrobeItem bottom;

  const SavedOutfit({
    required this.top,
    required this.bottom,
  });

  String get id => '${top.id}__${bottom.id}';
}

/// ---------- Home ----------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ClosetCategory selectedCategory = ClosetCategory.tops;

  WardrobeItem? selectedTop;
  WardrobeItem? selectedBottom;

  AvatarBodyType? _lastBodyType;

  final List<SavedOutfit> _favouriteOutfits = [];

  String _favouritesStorageKey(AvatarBodyType bodyType) =>
      'textyle.favourites.${bodyType.name}';

  bool get _currentOutfitIsFavourite {
    final top = selectedTop;
    final bottom = selectedBottom;
    if (top == null || bottom == null) return false;

    final id = '${top.id}__${bottom.id}';
    return _favouriteOutfits.any((outfit) => outfit.id == id);
  }

  void _loadFavouritesForBody(AvatarBodyType bodyType) {
    final availableItems = wardrobeItemsFor(bodyType);
    final itemsById = <String, WardrobeItem>{
      for (final item in availableItems) item.id: item,
    };

    final raw = html.window.localStorage[_favouritesStorageKey(bodyType)];

    _favouriteOutfits.clear();

    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final seen = <String>{};

      for (final entry in decoded) {
        if (entry is! Map) continue;

        final topId = entry['topId']?.toString();
        final bottomId = entry['bottomId']?.toString();

        if (topId == null || bottomId == null) continue;

        final top = itemsById[topId];
        final bottom = itemsById[bottomId];

        if (top == null ||
            bottom == null ||
            top.category != ClosetCategory.tops ||
            bottom.category != ClosetCategory.bottoms) {
          continue;
        }

        final outfit = SavedOutfit(top: top, bottom: bottom);
        if (seen.add(outfit.id)) {
          _favouriteOutfits.add(outfit);
        }
      }
    } catch (_) {
      // Ignore malformed/stale saved data and start with an empty list.
      _favouriteOutfits.clear();
    }
  }

  void _persistFavourites() {
    final bodyType = context.read<AvatarSettings>().bodyType;
    final payload = _favouriteOutfits
        .map(
          (outfit) => <String, String>{
            'topId': outfit.top.id,
            'bottomId': outfit.bottom.id,
          },
        )
        .toList(growable: false);

    html.window.localStorage[_favouritesStorageKey(bodyType)] =
        jsonEncode(payload);
  }

  void _toggleFavouriteOutfit() {
    final top = selectedTop;
    final bottom = selectedBottom;

    if (top == null || bottom == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
            content: Text('Choose a top and bottom before saving an outfit'),
          ),
        );
      return;
    }

    final currentId = '${top.id}__${bottom.id}';
    final existingIndex = _favouriteOutfits.indexWhere(
      (outfit) => outfit.id == currentId,
    );

    final wasSaved = existingIndex >= 0;

    setState(() {
      if (wasSaved) {
        _favouriteOutfits.removeAt(existingIndex);
      } else {
        // Newest saves appear first in the Favourites sheet.
        _favouriteOutfits.insert(
          0,
          SavedOutfit(top: top, bottom: bottom),
        );
      }
    });

    _persistFavourites();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          content: Text(
            wasSaved
                ? 'Removed from favourites'
                : 'Outfit saved to favourites',
          ),
        ),
      );
  }

  void _applyFavouriteOutfit(SavedOutfit outfit) {
    setState(() {
      selectedTop = outfit.top;
      selectedBottom = outfit.bottom;
    });

    Navigator.of(context).pop();
  }

  void _removeFavouriteOutfit(SavedOutfit outfit) {
    setState(() {
      _favouriteOutfits.removeWhere((saved) => saved.id == outfit.id);
    });

    _persistFavourites();
  }

  void _showFavourites() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FBFF),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Favourites',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_favouriteOutfits.length} saved',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_favouriteOutfits.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 44),
                          child: Column(
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                size: 38,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No saved outfits yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Tap the bookmark beside the avatar to save an outfit here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _favouriteOutfits.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final outfit = _favouriteOutfits[index];

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => _applyFavouriteOutfit(outfit),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      14, 12, 8, 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.82),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _FavouritePiecePreview(item: outfit.top),
                                        const SizedBox(width: 7),
                                        _FavouritePiecePreview(item: outfit.bottom),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${outfit.top.label} + ${outfit.bottom.label}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Tap to wear this outfit',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove favourite',
                                          onPressed: () {
                                            _removeFavouriteOutfit(outfit);
                                            setSheetState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.bookmark_remove_outlined,
                                            color: AppColors.primary,
                                            size: 21,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bodyType = context.watch<AvatarSettings>().bodyType;
    if (_lastBodyType == bodyType) return;

    _lastBodyType = bodyType;

    // Switching avatar body starts from a clean outfit slate.
    selectedTop = null;
    selectedBottom = null;

    // Each avatar body keeps its own compatible saved-outfit collection.
    _loadFavouritesForBody(bodyType);
  }

  List<WardrobeItem> get visibleItems {
    final bodyType = context.read<AvatarSettings>().bodyType;
    return wardrobeItemsFor(bodyType)
        .where((item) => item.category == selectedCategory)
        .toList();
  }

  void _selectItem(WardrobeItem item) {
    setState(() {
      if (item.category == ClosetCategory.tops) {
        selectedTop = item;
      } else {
        selectedBottom = item;
      }
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HomeHeader(),

            const SizedBox(height: 26),

            const Text(
              "Today's fit",
              style: TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Style your outfit from your closet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 28),

            _FloatingOutfitHero(
              selectedTop: selectedTop,
              selectedBottom: selectedBottom,
              isFavourite: _currentOutfitIsFavourite,
              onFavouriteTap: _toggleFavouriteOutfit,
              onWeatherTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WeatherDetailPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            _SelectedPiecesRow(
              selectedTop: selectedTop,
              selectedBottom: selectedBottom,
              onSelectItem: _selectItem,
            ),

            const SizedBox(height: 14),

            _DispenseOutfitButton(
              onTap: () {
                // later this will send selectedTop + selectedBottom to the hardware closet
              },
            ),

          const SizedBox(height: 22),

            Row(
              children: [
                const Text(
                  'Closet',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showFavourites,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Favourites',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (_favouriteOutfits.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${_favouriteOutfits.length}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

           _HomeClosetGrid(
  selectedCategory: selectedCategory,
  onCategoryChanged: (category) {
    setState(() {
      selectedCategory = category;
    });
  },
  items: visibleItems,
  selectedTop: selectedTop,
  selectedBottom: selectedBottom,
  onSelectItem: _selectItem,
),
          ],
        ),
      ),
    ),
  );
}
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HomeHeaderPillButton(
          icon: Icons.logout_rounded,
          label: 'Log out',
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthPage()),
            );
          },
        ),

        const Spacer(),

        _HomeHeaderPillButton(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
      ],
    );
  }
}


class _MiniWeatherBadge extends StatefulWidget {
  final VoidCallback onTap;

  const _MiniWeatherBadge({
    required this.onTap,
  });

  @override
  State<_MiniWeatherBadge> createState() => _MiniWeatherBadgeState();
}

class _MiniWeatherBadgeState extends State<_MiniWeatherBadge> {
  late final Future<Map<String, dynamic>> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = fetchHamiltonWeather();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        final hasWeather = snapshot.hasData;

        final temp = hasWeather
            ? (snapshot.data!['temperature_2m'] as num).round()
            : null;

        final code = hasWeather
            ? (snapshot.data!['weather_code'] as num).toInt()
            : 0;

        final isDay = hasWeather
            ? (snapshot.data!['is_day'] as num).toInt()
            : 1;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 72,
                minHeight: 52,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasWeather
                          ? weatherIcon(code, isDay)
                          : Icons.cloud_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasWeather ? '$temp°' : '--°',
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HomeHeaderPillButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Back',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: AppColors.textDark,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Manage your account and smart closet settings.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 26),

                Center(
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.82),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.95),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                const Center(
                  child: Text(
                    'textyle user',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                      color: AppColors.textDark,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                const Center(
                  child: Text(
                    'user@email.com',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

_ProfileSection(
  title: 'Avatar',
  children: const [
    _AvatarBodySelector(),
  ],
),

const SizedBox(height: 18),

                _ProfileSection(
                  title: 'Account',
                  children: [
                    _ProfileInfoTile(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: 'user@email.com',
                      onTap: () {},
                    ),
                    _ProfileInfoTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Password',
                      subtitle: 'Change your password',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _ProfileSection(
                  title: 'Smart closet',
                  children: [
                    _ProfileInfoTile(
                      icon: Icons.wifi_rounded,
                      title: 'Internet',
                      subtitle: 'Connected',
                      onTap: () {},
                    ),
                    _ProfileInfoTile(
                      icon: Icons.sensors_rounded,
                      title: 'RFID reader',
                      subtitle: 'Ready to pair clothing tags',
                      onTap: () {},
                    ),
                    _ProfileInfoTile(
                      icon: Icons.inventory_2_outlined,
                      title: 'Hardware closet',
                      subtitle: 'Manage closet connection',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _ProfileSection(
                  title: 'Preferences',
                  children: [
                    _ProfileInfoTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Outfit and closet updates',
                      onTap: () {},
                    ),
                    _ProfileInfoTile(
                      icon: Icons.palette_outlined,
                      title: 'App theme',
                      subtitle: 'Clean light mode',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, size: 19),
                    label: const Text('Log out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.68),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.92),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: AppColors.textDark,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBodySelector extends StatelessWidget {
  const _AvatarBodySelector();

  @override
  Widget build(BuildContext context) {
    final selectedType = context.watch<AvatarSettings>().bodyType;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AvatarBodyOption(
              label: 'Male',
              icon: Icons.male_rounded,
              selected: selectedType == AvatarBodyType.male,
              onTap: () {
                context.read<AvatarSettings>().setBodyType(
                      AvatarBodyType.male,
                    );
              },
            ),
          ),
          Expanded(
            child: _AvatarBodyOption(
              label: 'Female',
              icon: Icons.female_rounded,
              selected: selectedType == AvatarBodyType.female,
              onTap: () {
                context.read<AvatarSettings>().setBodyType(
                      AvatarBodyType.female,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBodyOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarBodyOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white.withOpacity(0.95) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ThreeDAvatarPreview extends StatefulWidget {
  final WardrobeItem? selectedTop;
  final WardrobeItem? selectedBottom;

  const _ThreeDAvatarPreview({
    super.key,
    required this.selectedTop,
    required this.selectedBottom,
  });

  @override
  State<_ThreeDAvatarPreview> createState() => _ThreeDAvatarPreviewState();
}

class _ThreeDAvatarPreviewState extends State<_ThreeDAvatarPreview> {
  // Flutter Web platform-view factories cannot be unregistered. Using one
  // static view type across login sessions leaves the next Home page pointing
  // at the iframe from the previous (disposed) session.
  //
  // Give every avatar preview instance its own view type and iframe instead.
  static int _nextViewerId = 0;

  late final String _viewType =
      'textyle-three-outfit-dynamic-${_nextViewerId++}';

  bool _viewRegistered = false;
  html.IFrameElement? _iframe;
  StreamSubscription<html.Event>? _iframeLoadSubscription;
  String? _lastAvatarAsset;

  double _pendingRotationDelta = 0;
  bool _rotationFrameScheduled = false;

  AvatarBodyType get _bodyType =>
      context.read<AvatarSettings>().bodyType;

  String get _topAsset =>
      widget.selectedTop?.modelAssetFor(_bodyType) ?? '';
  String get _bottomAsset =>
      widget.selectedBottom?.modelAssetFor(_bodyType) ?? '';

  String _buildViewerSource(String avatarAsset) {
    return Uri(
      path: '/outfit_viewer.html',
      queryParameters: <String, String>{
        'avatar': avatarAsset,
        if (_topAsset.isNotEmpty) 'top': _topAsset,
        if (_bottomAsset.isNotEmpty) 'bottom': _bottomAsset,
      },
    ).toString();
  }

  void _registerViewer(String avatarAsset) {
    if (_viewRegistered) return;
    _viewRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = _buildViewerSource(avatarAsset)
          ..setAttribute('scrolling', 'no')
          ..setAttribute('allow', 'fullscreen');

        iframe.style
          ..width = '100%'
          ..height = '100%'
          ..border = '0'
          ..backgroundColor = 'transparent'
          ..pointerEvents = 'none'
          ..touchAction = 'none';

        _iframe = iframe;
        _iframeLoadSubscription?.cancel();
        _iframeLoadSubscription =
            iframe.onLoad.listen((_) => _syncEntireOutfit());
        return iframe;
      },
    );
  }

  void _postMessage(Map<String, Object> message) {
    _iframe?.contentWindow?.postMessage(message, '*');
  }

  void _syncEntireOutfit() {
    if (!mounted) return;

    final avatarAsset = context.read<AvatarSettings>().avatarAsset;
    _postMessage(<String, Object>{
      'type': 'textyle-set-body-outfit',
      'avatar': avatarAsset,
      'top': _topAsset,
      'bottom': _bottomAsset,
    });
  }

  void _sendToViewer(Map<String, Object> message) {
    if (!mounted || _iframe == null) return;
    _postMessage(message);
  }

  void _queueRotation(double deltaX) {
    _pendingRotationDelta += deltaX;
    if (_rotationFrameScheduled) return;

    _rotationFrameScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _rotationFrameScheduled = false;
      if (!mounted) return;

      final delta = _pendingRotationDelta;
      _pendingRotationDelta = 0;

      if (delta.abs() < 0.01) return;
      _postMessage(<String, Object>{
        'type': 'textyle-rotate-avatar',
        'deltaX': delta,
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final avatarAsset = context.read<AvatarSettings>().avatarAsset;
    if (_lastAvatarAsset == avatarAsset) return;

    _lastAvatarAsset = avatarAsset;
    _sendToViewer(<String, Object>{
      'type': 'textyle-set-body-outfit',
      'avatar': avatarAsset,
      'top': _topAsset,
      'bottom': _bottomAsset,
    });
  }

  @override
  void didUpdateWidget(covariant _ThreeDAvatarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedTop?.modelFileName !=
        widget.selectedTop?.modelFileName) {
      _sendToViewer(<String, Object>{
        'type': 'textyle-set-top',
        'asset': _topAsset,
      });
    }

    if (oldWidget.selectedBottom?.modelFileName !=
        widget.selectedBottom?.modelFileName) {
      _sendToViewer(<String, Object>{
        'type': 'textyle-set-bottom',
        'asset': _bottomAsset,
      });
    }
  }

  @override
  void dispose() {
    _iframeLoadSubscription?.cancel();
    _iframeLoadSubscription = null;

    final iframe = _iframe;
    _iframe = null;
    if (iframe != null) {
      iframe.src = 'about:blank';
      iframe.remove();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarAsset = context.watch<AvatarSettings>().avatarAsset;
    _registerViewer(avatarAsset);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        _queueRotation(details.delta.dx);
      },
      child: SizedBox(
        width: 300,
        height: 400,
        child: ClipRect(
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}

class _FloatingOutfitHero extends StatelessWidget {
  final WardrobeItem? selectedTop;
  final WardrobeItem? selectedBottom;
  final bool isFavourite;
  final VoidCallback onFavouriteTap;
  final VoidCallback onWeatherTap;

  const _FloatingOutfitHero({
    required this.selectedTop,
    required this.selectedBottom,
    required this.isFavourite,
    required this.onFavouriteTap,
    required this.onWeatherTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -8,
            left: -2,
            child: _MiniWeatherBadge(
              onTap: onWeatherTap,
            ),
          ),
          Positioned(
            bottom: -14,
            right: -4,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: _PlainHomeIconButton(
                  icon: isFavourite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  iconSize: 25,
                  onTap: onFavouriteTap,
                ),
              ),
            ),
          ),
          Positioned(
            top: 15,
            left: 0,
            right: 0,
            child: Center(
              child: _ThreeDAvatarPreview(
                selectedTop: selectedTop,
                selectedBottom: selectedBottom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ModelPreviewFallback extends StatelessWidget {
  final double size;

  const _ModelPreviewFallback({
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.view_in_ar_rounded,
        size: size,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _FavouritePiecePreview extends StatelessWidget {
  final WardrobeItem item;

  const _FavouritePiecePreview({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.95),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: _ClothingModelThumbnail(
          key: ValueKey<String>('favourite-uniform-${item.id}'),
          item: item,
          fallback: const _ModelPreviewFallback(size: 26),
        ),
      ),
    );
  }
}

class _DispenseOutfitButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DispenseOutfitButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 36,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.38),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary,
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.22),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.75),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.checkroom_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                'Dispense outfit',
                style: TextStyle(
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPiecesRow extends StatelessWidget {
  final WardrobeItem? selectedTop;
  final WardrobeItem? selectedBottom;
  final ValueChanged<WardrobeItem> onSelectItem;

  const _SelectedPiecesRow({
    required this.selectedTop,
    required this.selectedBottom,
    required this.onSelectItem,
  });

  void _showInventoryPicker(
    BuildContext context, {
    required ClosetCategory category,
    required String title,
  }) {
    final bodyType = context.read<AvatarSettings>().bodyType;
    final items = wardrobeItemsFor(bodyType)
        .where((item) => item.category == category)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag:true,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (_) {
        return _InventoryPickerSheet(
          title: title,
          items: items,
          selectedItem:
              category == ClosetCategory.tops ? selectedTop : selectedBottom,
          onSelectItem: (item) {
            Navigator.of(context).pop();
            onSelectItem(item);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SelectedPieceMiniCard(
            label: 'Top',
            item: selectedTop,
            onTap: () {
              _showInventoryPicker(
                context,
                category: ClosetCategory.tops,
                title: 'Choose a top',
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SelectedPieceMiniCard(
            label: 'Bottom',
            item: selectedBottom,
            onTap: () {
              _showInventoryPicker(
                context,
                category: ClosetCategory.bottoms,
                title: 'Choose a bottom',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SelectedPieceMiniCard extends StatelessWidget {
  final String label;
  final WardrobeItem? item;
  final VoidCallback onTap;

  const _SelectedPieceMiniCard({
    required this.label,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final piece = item;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.fromLTRB(10, 7, 16, 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.96),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: piece == null
                      ? AppColors.surface
                      : piece.color.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: piece == null
                    ? const Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: AppColors.primary,
                      )
                    : _ClothingModelThumbnail(
                        key: ValueKey<String>('selected-pill-3d-${piece.id}'),
                        item: piece,
                        fallback: const _ModelPreviewFallback(size: 24),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      piece?.label ?? 'Choose ${label.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: piece == null
                            ? AppColors.primary
                            : AppColors.textDark,
                      ),
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
}

class _InventoryPickerSheet extends StatelessWidget {
  final String title;
  final List<WardrobeItem> items;
  final WardrobeItem? selectedItem;
  final ValueChanged<WardrobeItem> onSelectItem;

  const _InventoryPickerSheet({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(34),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item.id == selectedItem?.id;

                    return _InventoryPickerTile(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => onSelectItem(item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryPickerTile extends StatelessWidget {
  final WardrobeItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _InventoryPickerTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.white.withOpacity(0.95),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: _ClothingModelThumbnail(
                  key: ValueKey<String>('picker-3d-${item.id}'),
                  item: item,
                  fallback: const _ModelPreviewFallback(size: 32),
                ),
              ),

              if (isSelected)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
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


class _HomeClosetGrid extends StatelessWidget {
  final ClosetCategory selectedCategory;
  final ValueChanged<ClosetCategory> onCategoryChanged;
  final List<WardrobeItem> items;
  final WardrobeItem? selectedTop;
  final WardrobeItem? selectedBottom;
  final ValueChanged<WardrobeItem> onSelectItem;

  const _HomeClosetGrid({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.items,
    required this.selectedTop,
    required this.selectedBottom,
    required this.onSelectItem,
  });

  void _showItemInfo(BuildContext context, WardrobeItem item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withOpacity(0.18),
    builder: (_) {
      return _ClothingInfoSheet(item: item);
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CleanCategorySwitcher(
          selectedCategory: selectedCategory,
          onChanged: onCategoryChanged,
        ),

        const SizedBox(height: 14),

        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            final isSelected =
                item.id == selectedTop?.id || item.id == selectedBottom?.id;

            return _ClosetGridTile(
              item: item,
              isSelected: isSelected,
              onTap: () => onSelectItem(item),
              onInfoTap: () => _showItemInfo(context, item),
            );
          },
        ),
      ],
    );
  }
}


class _PlainHomeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _PlainHomeIconButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Icon(
            icon,
            color: AppColors.primary,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class _HomeHeaderPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeHeaderPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.58),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.018),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// This class is used by Inventory / Weather / Upload too.
/// Keep it in the file even though the Home page uses the glassier buttons below.
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
          border: Border.all(color: Colors.white.withOpacity(0.88)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }
}

class _CleanCategorySwitcher extends StatelessWidget {
  final ClosetCategory selectedCategory;
  final ValueChanged<ClosetCategory> onChanged;

  const _CleanCategorySwitcher({
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isTops = selectedCategory == ClosetCategory.tops;

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.95),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: isTops ? 0 : segmentWidth,
                top: 0,
                width: segmentWidth,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onChanged(ClosetCategory.tops),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isTops
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                            child: const Text('Tops'),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onChanged(ClosetCategory.bottoms),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: !isTops
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                            child: const Text('Bottoms'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}


class _ClothingModelThumbnail extends StatefulWidget {
  final WardrobeItem item;
  final Widget fallback;

  const _ClothingModelThumbnail({
    super.key,
    required this.item,
    required this.fallback,
  });

  @override
  State<_ClothingModelThumbnail> createState() =>
      _ClothingModelThumbnailState();
}

class _ClothingModelThumbnailState extends State<_ClothingModelThumbnail> {
  static int _nextFactoryId = 0;
  static final Map<String, String> _viewTypesByAsset = <String, String>{};

  String? _modelAsset;
  String? _viewType;
  AvatarBodyType? _lastBodyType;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bodyType = context.watch<AvatarSettings>().bodyType;
    if (_lastBodyType == bodyType && _modelAsset != null) return;

    _lastBodyType = bodyType;
    _configureThumbnail(bodyType);
  }

  @override
  void didUpdateWidget(covariant _ClothingModelThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.modelFileName != widget.item.modelFileName) {
      _configureThumbnail(
        context.read<AvatarSettings>().bodyType,
      );
    }
  }

  void _configureThumbnail(AvatarBodyType bodyType) {
    _modelAsset = _resolveModelAsset(widget.item, bodyType);
    _viewType = _modelAsset == null
        ? null
        : _ensureViewFactory(_modelAsset!);
  }

  String? _resolveModelAsset(
    WardrobeItem item,
    AvatarBodyType bodyType,
  ) {
    final asset = item.modelAssetFor(bodyType);
    if (asset == null || !asset.toLowerCase().endsWith('.glb')) {
      return null;
    }
    return asset;
  }

  static String _ensureViewFactory(String modelAsset) {
    final existing = _viewTypesByAsset[modelAsset];
    if (existing != null) return existing;

    final viewType = 'closet-model-factory-${_nextFactoryId++}';
    final source = Uri(
      path: '/model_thumb.html',
      queryParameters: <String, String>{'model': modelAsset},
    ).toString();

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        return html.IFrameElement()
          ..src = source
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = '0'
          ..style.backgroundColor = 'transparent'
          ..style.pointerEvents = 'none'
          ..setAttribute('scrolling', 'no')
          ..setAttribute('aria-hidden', 'true');
      },
    );

    _viewTypesByAsset[modelAsset] = viewType;
    return viewType;
  }

  @override
  Widget build(BuildContext context) {
    if (_viewType == null) {
      return Center(child: widget.fallback);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: IgnorePointer(
        child: HtmlElementView(viewType: _viewType!),
      ),
    );
  }
}

class _ClosetGridTile extends StatelessWidget {
  final WardrobeItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _ClosetGridTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onInfoTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _ClothingModelThumbnail(
                key: ValueKey<String>('closet-3d-${item.id}'),
                item: item,
                fallback: const _ModelPreviewFallback(size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClothingInfoSheet extends StatelessWidget {
  final WardrobeItem item;

  const _ClothingInfoSheet({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                color: const Color(0xFFDCE6F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            const SizedBox(height: 22),

            Container(
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: _ClothingModelThumbnail(
                key: ValueKey<String>('info-sheet-3d-${item.id}'),
                item: item,
                fallback: const _ModelPreviewFallback(size: 30),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '${item.categoryLabel} · ${item.season}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: _InfoStatCard(
                    icon: Icons.history_rounded,
                    title: 'Last worn',
                    value: item.lastWornLabel.replaceFirst('Worn ', ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoStatCard(
                    icon: Icons.local_laundry_service_outlined,
                    title: 'Last washed',
                    value: item.lastWashedLabel.replaceFirst('Washed ', ''),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                item.notes,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
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

class _InfoStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8A9097),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}


class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 26,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withOpacity(0.86),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

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
    List<WardrobeItem> items = [
      ...wardrobeItemsFor(context.watch<AvatarSettings>().bodyType),
    ];

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
    final items = [
      ...wardrobeItemsFor(context.read<AvatarSettings>().bodyType),
    ];

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
          padding: const EdgeInsets.fromLTRB(18, 60, 18, 0),
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
                        cacheExtent: 0,
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 92),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _InventoryRowCard(
                            key: ValueKey<String>('inventory-row-${items[index].id}'),
                            item: items[index],
                          );
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

  const _InventoryRowCard({
    super.key,
    required this.item,
  });

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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _ClothingModelThumbnail(
                    key: ValueKey<String>('inventory-3d-${item.id}'),
                    item: item,
                    fallback: const _ModelPreviewFallback(size: 28),
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
                    clipBehavior: Clip.antiAlias,
                    child: _ClothingModelThumbnail(
                      key: ValueKey<String>('inventory-detail-3d-${item.id}'),
                      item: item,
                      fallback: const _ModelPreviewFallback(size: 30),
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
    weatherFuture = fetchHamiltonWeatherForecast();
  }

  Future<void> refreshWeather() async {
    final refreshed = fetchHamiltonWeatherForecast();
    setState(() {
      weatherFuture = refreshed;
    });
    await refreshed;
  }

  List<int> _next24HourIndexes(
    Map<String, dynamic> hourly,
    String currentTime,
  ) {
    final times = List<String>.from(hourly['time'] as List);
    final now = DateTime.parse(currentTime);
    final indexes = <int>[];

    for (int i = 0; i < times.length; i++) {
      final time = DateTime.parse(times[i]);

      if (!time.isBefore(now)) {
        indexes.add(i);
      }

      if (indexes.length == 24) break;
    }

    return indexes;
  }

  String _buildClothingAdvice({
    required double currentTemp,
    required List<int> indexes,
    required Map<String, dynamic> hourly,
  }) {
    final temps = List<num>.from(hourly['temperature_2m'] as List);
    final pops = List<num>.from(hourly['precipitation_probability'] as List);
    final codes = List<num>.from(hourly['weather_code'] as List);
    final winds = List<num>.from(hourly['wind_speed_10m'] as List);

    if (indexes.isEmpty) {
      return 'Weather data is limited right now. Dress based on the current conditions.';
    }

    final futureTemps = indexes.map((i) => temps[i].toDouble()).toList();
    final futurePops = indexes.map((i) => pops[i].toInt()).toList();
    final futureCodes = indexes.map((i) => codes[i].toInt()).toList();
    final futureWinds = indexes.map((i) => winds[i].toDouble()).toList();

    final maxPop = futurePops.reduce((a, b) => a > b ? a : b);
    final maxWind = futureWinds.reduce((a, b) => a > b ? a : b);
    final minTemp = futureTemps.reduce((a, b) => a < b ? a : b);
    final maxTemp = futureTemps.reduce((a, b) => a > b ? a : b);
    final tempSwing = (maxTemp - minTemp).abs();

    final hasRainCode = futureCodes.any(
      (code) =>
          (code >= 51 && code <= 67) ||
          (code >= 80 && code <= 82) ||
          code == 95,
    );

    if (maxPop >= 60 || hasRainCode) {
      return 'Rain is possible later. Consider a waterproof layer, darker bottoms, or shoes you do not mind getting wet.';
    }

    if (tempSwing >= 6) {
      return 'The temperature may shift over the next 24 hours. A light layer would help if conditions change.';
    }

    if (maxWind >= 28) {
      return 'It may get windy. Avoid loose layers and consider something more structured.';
    }

    if (currentTemp >= 26) {
      return 'It is warm today. Lightweight tops and breathable fabrics are the safest choice.';
    }

    if (currentTemp <= 10) {
      return 'It is chilly today. Choose warmer layers before heading out.';
    }

    return 'Weather looks steady over the next 24 hours. Your outfit should be comfortable without extra preparation.';
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
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
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
                        'Weather',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'Hamilton forecast for your outfit',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
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
                            padding: EdgeInsets.all(22),
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

                    final data = snapshot.data!;
                    final current = Map<String, dynamic>.from(data['current'] as Map);
                    final hourly = Map<String, dynamic>.from(data['hourly'] as Map);

                    final temp = (current['temperature_2m'] as num).toDouble();
                    final humidity = current['relative_humidity_2m'];
                    final wind = (current['wind_speed_10m'] as num).toDouble();
                    final code = current['weather_code'] as int;
                    final isDay = current['is_day'] as int;
                    final time = current['time'] as String;

                    final indexes = _next24HourIndexes(hourly, time);

                    final advice = _buildClothingAdvice(
                      currentTemp: temp,
                      indexes: indexes,
                      hourly: hourly,
                    );

                    return Column(
                      children: [
                        _Card(
                          child: Column(
                            children: [
                              Icon(
                                weatherIcon(code, isDay),
                                size: 58,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Hamilton, ON',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${temp.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                weatherDescription(code),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _WeatherStat(
                                      icon: Icons.water_drop_outlined,
                                      label: 'Humidity',
                                      value: '$humidity%',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _WeatherStat(
                                      icon: Icons.air_rounded,
                                      label: 'Wind',
                                      value: '${wind.toStringAsFixed(0)} km/h',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.checkroom_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Outfit advice',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                advice,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Next 24 hours',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _HourlyForecastRow(
                                hourly: hourly,
                                indexes: indexes,
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _HourlyForecastRow extends StatelessWidget {
  final Map<String, dynamic> hourly;
  final List<int> indexes;

  const _HourlyForecastRow({
    required this.hourly,
    required this.indexes,
  });

  @override
  Widget build(BuildContext context) {
    final times = List<String>.from(hourly['time'] as List);
    final temps = List<num>.from(hourly['temperature_2m'] as List);
    final pops = List<num>.from(hourly['precipitation_probability'] as List);
    final codes = List<num>.from(hourly['weather_code'] as List);

    if (indexes.isEmpty) {
      return const Text(
        'Hourly forecast data is unavailable right now.',
        style: TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: indexes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, itemIndex) {
          final i = indexes[itemIndex];
          final dateTime = DateTime.parse(times[i]);
          final hour = dateTime.hour;
          final hourLabel = hour == 0
              ? '12 AM'
              : hour < 12
                  ? '$hour AM'
                  : hour == 12
                      ? '12 PM'
                      : '${hour - 12} PM';

          final temp = temps[i].round();
          final pop = pops[i].round();
          final code = codes[i].toInt();

          return Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hourLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
                Icon(
                  weatherIcon(code, 1),
                  color: AppColors.primary,
                  size: 22,
                ),
                Text(
                  '$temp°C',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '$pop% rain',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: pop >= 50
                        ? Colors.redAccent
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
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

  XFile? _frontImage;
  XFile? _backImage;
  bool _pickingFront = true;
  String? _pairedRfidTag;

  bool _isPicking = false;
  bool _isScanningRfid = false;

  bool get _canSave {
  return _frontImage != null &&
      _backImage != null &&
      _pairedRfidTag != null;
}

  Future<void> _pickImage(ImageSource source) async {
  try {
    setState(() {
      _isPicking = true;
    });

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 92,
    );

    if (!mounted || file == null) return;

    final accepted = await _reviewPickedImage(
      file: file,
      front: _pickingFront,
    );

    if (!mounted || !accepted) return;

    setState(() {
      if (_pickingFront) {
        _frontImage = file;
      } else {
        _backImage = file;
      }
    });
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

Future<bool> _reviewPickedImage({
  required XFile file,
  required bool front,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAF8),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFF151817)),
                      Center(
                        child: Image.network(
                          file.path,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white70,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.black.withOpacity(0.28),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(dialogContext, false),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Retake',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Use photo',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}

Future<void> _showCaptureGuide({
  required bool front,
  required ImageSource source,
}) async {
  final continueCapture = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.30),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.only(top: 32),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: const Color(0xFF161B19),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: Icon(
                    source == ImageSource.camera
                        ? Icons.camera_alt_outlined
                        : Icons.photo_library_outlined,
                    size: 20,
                  ),
                  label: Text(
                    source == ImageSource.camera
                        ? 'Continue to camera'
                        : 'Choose photo',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (continueCapture == true && mounted) {
    await _pickImage(source);
  }
}

void _showImageSourceSheet({required bool front}) {
  setState(() {
    _pickingFront = front;
  });

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.18),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(30),
          ),
        ),
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
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                front ? 'Add front photo' : 'Add back photo',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                front
                    ? 'Upload the front side of the clothing item.'
                    : 'Upload the back side of the clothing item.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 18),

              _TypeChoiceTile(
                label: 'Choose from gallery',
                subtitle: 'Pick an existing photo',
                icon: Icons.photo_library_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _showCaptureGuide(
                    front: front,
                    source: ImageSource.gallery,
                  );
                },
              ),

              const SizedBox(height: 10),

              _TypeChoiceTile(
                label: 'Take a photo',
                subtitle: 'Use your camera',
                icon: Icons.camera_alt_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _showCaptureGuide(
                    front: front,
                    source: ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Future<void> _scanRfidTag() async {
    if (_frontImage == null || _backImage == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Add front and back photos before pairing an RFID tag'),
      duration: Duration(milliseconds: 1200),
    ),
  );
  return;
}

    setState(() {
      _isScanningRfid = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final fakeTag =
        'RFID-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    setState(() {
      _pairedRfidTag = fakeTag;
      _isScanningRfid = false;
    });
  }

ClothingType _detectClothingType() {
  return ClothingType.top;
}

  void _savePickedItem() {
    if (!_canSave) return;

    final fileName = _frontImage!.name;
    final dotIndex = fileName.lastIndexOf('.');
    final displayName =
        dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;

    context.read<InventoryStore>().addItem(
          ClothingItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: _detectClothingType(),
            name: displayName.isEmpty ? 'New Item' : displayName,
            colorLabel: 'RFID: $_pairedRfidTag',
            originalImagePath: _frontImage!.path,
          ),
        );
    // );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item saved to closet + hardware'),
        duration: Duration(milliseconds: 1000),
      ),
    );

    setState(() {
  _frontImage = null;
  _backImage = null;
  _pairedRfidTag = null;
});
  }

Widget _buildSidePhotoCard({
  required String title,
  required String subtitle,
  required XFile? image,
  required bool front,
}) {
  final hasImage = image != null;

  return Expanded(
  child: GestureDetector(
    onTap: _isPicking ? null : () => _showImageSourceSheet(front: front),
    child: SizedBox(
      height: 150,
      child: Container(
        padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: hasImage
                  ? AppColors.primary.withOpacity(0.40)
                  : Colors.white.withOpacity(0.95),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Image.network(
                          image.path,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) {
                            return const Center(
                              child: Icon(
                                Icons.image_rounded,
                                color: AppColors.primary,
                                size: 42,
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.92),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              front
                                  ? Icons.flip_to_front_rounded
                                  : Icons.flip_to_back_rounded,
                              color: AppColors.primary,
                              size: 30,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
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

  @override
  Widget build(BuildContext context) {
    final hasFrontImage = _frontImage != null;
    final hasBackImage = _backImage != null;
    final hasBothImages = hasFrontImage && hasBackImage;
    final hasRfid = _pairedRfidTag != null;

    return Container(
      decoration: appBackground(),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add clothing',
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Pair each real piece with your smart closet',
                maxLines:1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 24),

             Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.72),
    borderRadius: BorderRadius.circular(34),
    border: Border.all(
      color: Colors.white.withOpacity(0.90),
      width: 1.1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.035),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  ),
  child: Column(
    children: [
      Row(
        children: [
          _buildSidePhotoCard(
            title: 'Front',
            subtitle: 'Tap to add front',
            image: _frontImage,
            front: true,
          ),
          const SizedBox(width: 12),
          _buildSidePhotoCard(
            title: 'Back',
            subtitle: 'Tap to add back',
            image: _backImage,
            front: false,
          ),
        ],
      ),
    ],
  ),
),
              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.88),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Item setup',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Connect this item to the physical closet.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),

                    const SizedBox(height: 16),


_SetupStatusRow(
  icon: Icons.flip_to_front_rounded,
  title: 'Front photo',
  value: hasFrontImage ? 'Added' : 'Missing',
  complete: hasFrontImage,
  onTap: _isPicking
      ? null
      : () => _showImageSourceSheet(front: true),
),

const SizedBox(height: 10),

_SetupStatusRow(
  icon: Icons.flip_to_back_rounded,
  title: 'Back photo',
  value: hasBackImage ? 'Added' : 'Missing',
  complete: hasBackImage,
  onTap: _isPicking
      ? null
      : () => _showImageSourceSheet(front: false),
),

const SizedBox(height: 10),

_SetupStatusRow(
  icon: Icons.sensors_rounded,
  title: 'RFID tag',
  value: hasRfid
      ? _pairedRfidTag!
      : _isScanningRfid
          ? 'Scanning...'
          : 'Not paired yet',
  complete: hasRfid,
  onTap: _isScanningRfid ? null : _scanRfidTag,
),

const SizedBox(height: 16),

                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canSave ? _savePickedItem : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.black.withOpacity(0.08),
                          disabledForegroundColor:
                              AppColors.textMuted.withOpacity(0.45),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                        _canSave
    ? 'Save to closet + hardware'
    : !hasFrontImage
        ? 'Add front photo first'
        : !hasBackImage
            ? 'Add back photo first'
            : !hasRfid
                ? 'Pair RFID tag first'
                : 'Save to closet + hardware',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
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
    );
  }
}

class _TypeChoiceTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeChoiceTile({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.9),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 22,
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),

                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupStatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool complete;
  final VoidCallback? onTap;

  const _SetupStatusRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.complete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: complete
                  ? AppColors.primary.withOpacity(0.22)
                  : Colors.transparent,
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.92),
                ),
                child: Icon(
                  complete ? Icons.check_rounded : icon,
                  color: isDisabled
                      ? AppColors.textMuted.withOpacity(0.45)
                      : AppColors.primary,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: isDisabled
                            ? AppColors.textMuted.withOpacity(0.55)
                            : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: complete
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
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
}
