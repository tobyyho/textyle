import 'package:flutter/material.dart';

void main() {
  runApp(const TextyleApp());
}

/// Root app
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
      home: const LoginPage(),
    );
  }
}

/// ---------- Shared theme helpers ----------
class AppColors {
  static const bg = Color(0xfff8f7f4);
  static const white = Colors.white;

  static const primary = Color(0xff0b7a69); // modern green/teal like screenshot
  static const primaryDark = Color(0xff075f52);

  static const textDark = Color(0xff1e1e1e);
  static const textMuted = Color(0xff7a7a7a);
  static const border = Color(0xffe7e5e1);
  static const fieldFill = Color(0xffffffff);
  static const hint = Color(0xffa1a1a1);

  static const navBg = Color(0xfff3d8db);
}

BoxDecoration appBackground() {
  return const BoxDecoration(
    color: AppColors.bg,
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
    ),
    filled: true,
    fillColor: AppColors.fieldFill,
    prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}

/// ---------- Login ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showPassword = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void _demoLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),

                /// Top clothing rack visual
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: 8,
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 0,
                          left: 14,
                          child: RackClothing(color: Color(0xfff1f1ef)),
                        ),
                        const Positioned(
                          top: 0,
                          left: 72,
                          child: RackClothing(color: Color(0xff0b8c79)),
                        ),
                        const Positioned(
                          top: 0,
                          left: 130,
                          child: RackClothing(color: Color(0xfff1f1ef)),
                        ),
                        const Positioned(
                          top: 0,
                          left: 188,
                          child: RackClothing(color: Color(0xff123f6b)),
                        ),
                        const Positioned(
                          top: 0,
                          left: 246,
                          child: RackClothing(color: Color(0xfff1f1ef)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 42),

                /// Logo
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 58,
                        child: Image.asset(
                          'assets/textyle_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.checkroom_rounded,
                              size: 42,
                              color: AppColors.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "more than just a walk-in",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 38),

                const Text(
                  "Email Address",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
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

                const SizedBox(height: 22),

                const Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
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

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.95,
                          child: Checkbox(
                            value: true,
                            onChanged: (_) {},
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
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

                const SizedBox(height: 18),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _demoLogin,
                    child: const Text(
                      "Sign In",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignUpPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Create account",
                        style: TextStyle(
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
      ),
    );
  }
}

class RackClothing extends StatelessWidget {
  final Color color;

  const RackClothing({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.checkroom_outlined,
          size: 22,
          color: Colors.grey.shade500,
        ),
        Transform.translate(
          offset: const Offset(0, -2),
          child: Icon(
            Icons.checkroom_rounded,
            size: 40,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// ---------- Sign up ----------
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool showPassword = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void _demoSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Join textyle and build your smart closet",
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: nameController,
                  decoration: modernFieldDecoration(
                    hint: "Full name",
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: modernFieldDecoration(
                    hint: "Email",
                    prefixIcon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: modernFieldDecoration(
                    hint: "Password",
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
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _demoSignUp,
                    child: const Text(
                      "Create Account",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
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

/// ---------- Main app scaffold with bottom nav ----------
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int index = 0;

  final pages = const [
    HomePage(),
    InventoryPage(),
    UploadPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: AppColors.navBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: "Home",
              icon: Icons.home_rounded,
              selected: index == 0,
              onTap: () => setState(() => index = 0),
            ),
            _NavItem(
              label: "Inventory",
              icon: Icons.inventory_2_rounded,
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.55) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                    MaterialPageRoute(builder: (_) => const LoginPage()),
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
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
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
          color: Colors.white.withOpacity(0.60),
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