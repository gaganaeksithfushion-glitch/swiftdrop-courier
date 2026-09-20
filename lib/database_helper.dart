#!/usr/bin/env bash

# Flutter project එකට නැතිවුණු android ෆෝල්ඩරය නැවත සාදා ගැනීම
flutter create . --platforms=android
flutter pub get
flutter build appbundle --release
flutter build apk --release
Recreating project ....
  swiftdrop_courier.iml (created)
  .gitignore (created)
  android/app/src/profile/AndroidManifest.xml (created)
  android/app/src/main/res/mipmap-mdpi/ic_launcher.png (created)
  android/app/src/main/res/mipmap-hdpi/ic_launcher.png (created)
  android/app/src/main/res/drawable/launch_background.xml (created)
  android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png (created)
  android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png (created)
  android/app/src/main/res/values-night/styles.xml (created)
  android/app/src/main/res/values/styles.xml (created)
  android/app/src/main/res/drawable-v21/launch_background.xml (created)
  android/app/src/main/res/mipmap-xhdpi/ic_launcher.png (created)
  android/app/src/debug/AndroidManifest.xml (created)
  android/settings.gradle.kts (created)
  android/gradle/wrapper/gradle-wrapper.properties (created)
  android/gradle.properties (created)
  android/.gitignore (created)
  android/build.gradle.kts (created)
  android/app/build.gradle.kts (created)
  android/app/src/main/kotlin/com/example/swiftdrop_courier/MainActivity.kt (created)
  android/swiftdrop_courier_android.iml (created)
  analysis_options.yaml (created)
  .idea/runConfigurations/main_dart.xml (created)
  .idea/libraries/Dart_SDK.xml (created)
  .idea/libraries/KotlinJavaRuntime.xml (created)
  .idea/modules.xml (created)
  .idea/workspace.xml (created)
  test/widget_test.dart (created)
Resolving dependencies...
Downloading packages...
Got dependencies.
Wrote 31 files.

All done!
You can find general documentation for Flutter at: https://docs.flutter.dev/
Detailed API documentation is available at: https://api.flutter.dev/
If you prefer video documentation, consider: https://www.youtube.com/c/flutterdev

In order to run your application, type:

  $ flutter run

Your application code is in ./lib/main.dart.

Resolving dependencies...
Downloading packages...
  code_assets 1.2.1 (2.1.0 available)
  csv 6.0.0 (8.0.0 available)
  flutter_lints 4.0.0 (6.0.0 available)
  geolocator 10.1.1 (14.0.3 available)
  geolocator_android 4.6.2 (5.0.3 available)
  geolocator_web 2.2.1 (4.1.4 available)
  hooks 2.0.2 (2.2.0 available)
  lints 4.0.0 (6.1.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.3 (1.19.0 available)
  objective_c 9.5.0 (9.6.0 available)
  permission_handler 11.4.0 (13.0.2 available)
  permission_handler_android 12.1.0 (14.1.0 available)
  qr 3.0.2 (4.0.0 available)
  record_use 0.6.0 (1.1.1 available)
  test_api 0.7.12 (0.7.14 available)
  vector_math 2.4.0 (2.4.3 available)
Got dependencies!
17 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Running Gradle task 'bundleRelease'...                          
Checking the license for package Android SDK Platform 36 in /usr/local/share/android-sdk/licenses
License for package Android SDK Platform 36 accepted.
Preparing "Install Android SDK Platform 36 (revision 2)".
"Install Android SDK Platform 36 (revision 2)" ready.
Installing Android SDK Platform 36 in /usr/local/share/android-sdk/platforms/android-36
"Install Android SDK Platform 36 (revision 2)" complete.
"Install Android SDK Platform 36 (revision 2)" finished.
lib/main.dart:170:83: Error: 'SmartScannerScreen' is imported from both 'package:swiftdrop_courier/pending_calls_screen.dart' and 'package:swiftdrop_courier/smart_scanner_screen.dart'.
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartScannerScreen()));
                                                                                  ^^^^^^^^^^^^^^^^^^
lib/main.dart:180:83: Error: Not a constant expression.
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingCallsScreen()));
                                                                                  ^^^^^^^^^^^^^^^^^^
lib/route_list_screen.dart:114:32: Error: The method 'updateDeliveryDetails' isn't defined for the type 'DatabaseHelper'.
 - 'DatabaseHelper' is from 'package:swiftdrop_courier/database_helper.dart' ('lib/database_helper.dart').
Try correcting the name to the name of an existing method, or defining a method named 'updateDeliveryDetails'.
                await dbHelper.updateDeliveryDetails(item['id'] as int, {
                               ^^^^^^^^^^^^^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command '/Users/builder/programs/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights from a Build Scan (powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 2m 26s
[=========                              ] 25%                                   
Running Gradle task 'bundleRelease'...                            147.4s
Gradle task bundleRelease failed with exit code 1
Running Gradle task 'assembleRelease'...                        
lib/main.dart:170:83: Error: 'SmartScannerScreen' is imported from both 'package:swiftdrop_courier/pending_calls_screen.dart' and 'package:swiftdrop_courier/smart_scanner_screen.dart'.
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartScannerScreen()));
                                                                                  ^^^^^^^^^^^^^^^^^^
lib/main.dart:180:83: Error: Not a constant expression.
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingCallsScreen()));
                                                                                  ^^^^^^^^^^^^^^^^^^
lib/route_list_screen.dart:114:32: Error: The method 'updateDeliveryDetails' isn't defined for the type 'DatabaseHelper'.
 - 'DatabaseHelper' is from 'package:swiftdrop_courier/database_helper.dart' ('lib/database_helper.dart').
Try correcting the name to the name of an existing method, or defining a method named 'updateDeliveryDetails'.
                await dbHelper.updateDeliveryDetails(item['id'] as int, {
                               ^^^^^^^^^^^^^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command '/Users/builder/programs/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights from a Build Scan (powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 7s
Running Gradle task 'assembleRelease'...                            8.0s
Gradle task assembleRelease failed with exit code 1


Build failed :|
Step 3 script `Create Android Native Files and Build` exited with status code 1
