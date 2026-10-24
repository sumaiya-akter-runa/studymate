/// FILE: lib/config.dart
/// PURPOSE: The one place that says where the backend lives.
///
/// Which address to use:
///  - Android EMULATOR : http://10.0.2.2:8000   (10.0.2.2 means "your PC" from inside the emulator)
///  - REAL PHONE       : http://YOUR_PC_WIFI_IP:8000, for example http://192.168.0.105:8000
///                       (run `ipconfig` on your PC and read "IPv4 Address";
///                        the phone and the PC must be on the same Wi-Fi

class AppConfig {
  static const String baseUrl =
      "https://studymate-backend-1uuf.onrender.com";
}
