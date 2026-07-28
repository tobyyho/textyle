TEXTYLE VISUAL BUILD — RUN FIRST

This zip contains a minimal Flutter project using your uploaded main.dart visuals.

WHAT THIS BUILD INCLUDES
- Your current Textyle visual prototype in lib/main.dart
- Minimal pubspec.yaml with the http dependency used by the weather widget

IMPORTANT
- The app references assets/textyle_logo.png, but main.dart already has an errorBuilder.
- That means if the logo file is missing, the app will still run and will show an icon instead.

HOW TO RUN IT

1) Download and unzip the folder
2) Open Terminal
3) cd into the unzipped project folder
4) Run these commands:

   flutter pub get
   flutter run -d chrome

If you want to use iOS Simulator instead:

   flutter pub get
   flutter run -d ios

If you want to check available devices first:

   flutter devices

WHAT YOU SHOULD EXPECT TO SEE

1. Auth screen
- Beige background
- Clothing rack at the top with draggable clothing pieces
- Logo/slogan under the rack
- Sign in card under the logo
- Tap Sign up / Log in to switch cards

2. Main app after sign in
- Bottom nav with Inventory, Home, Upload
- Inventory page with glassmorphism cards
- Home page with avatar and outfit selector
- Upload page in the same visual style

NOTES
- This is the visual prototype only
- It does not yet include the full upload-to-inventory-to-avatar asset pipeline
- Weather pulls from Open-Meteo, so internet helps for the weather widget
- The sign in button currently moves straight into the main app flow

IF FLUTTER CACHING ACTS UP
Run:

   flutter clean
   flutter pub get
   flutter run -d chrome
