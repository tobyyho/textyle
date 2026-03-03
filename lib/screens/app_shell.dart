import 'package:flutter/material.dart';
import 'inventory_screen.dart';

class AppShell extends StatefulWidget {
  final VoidCallback onLogout;
  const AppShell({super.key, required this.onLogout});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboard(onLogout: widget.onLogout),
      const InventoryScreen(),
      const UploadScreen(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.add_a_photo_outlined), label: 'Upload'),
        ],
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  final VoidCallback onLogout;
  const HomeDashboard({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Text('Today', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: onLogout, icon: const Icon(Icons.logout)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Closet Status: Not connected (demo)', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Outfit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(width: 70, child: Text('Top:', style: TextStyle(fontWeight: FontWeight.w700))),
                    Text('White Button-Down'),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    SizedBox(width: 70, child: Text('Bottom:', style: TextStyle(fontWeight: FontWeight.w700))),
                    Text('Charcoal Trousers'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap “Present Outfit” to simulate the closet rotating + spotlighting.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Demo: Presenting outfit (spotlight + rotate)')),
                          );
                        },
                        child: const Text('Present Outfit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Demo: Outfit picker (coming next)')),
                          );
                        },
                        child: const Text('Pick Outfit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.checkroom),
            label: const Text('Open Inventory'),
          ),

          const SizedBox(height: 22),
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('Side Intake (demo)'),
            subtitle: const Text('Hang clean clothes → system auto-sorts (later)'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Calibrate (demo)'),
            subtitle: const Text('Assign hooks to shirt/pants zones (later)'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('Next: camera/photo upload → inventory item.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera upload coming next')),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ],
        ),
      ),
    );
  }
}