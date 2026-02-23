# PiliPro - Agentic Coding Guide

## Project Overview

**PiliPro** (also referred to as PiliPlus) is a high-performance third-party BiliBili client developed with Flutter.

- **Project Type**: Flutter mobile application
- **Supported Platforms**: 
  - ✅ Android 10+ (actively maintained)
  - ✅ iOS 17+ (actively maintained)
  - ❌ Windows, Linux, macOS (DEPRECATED - no longer maintained)
- **Current Version**: 1.1.6
- **Flutter Version**: 3.41.0 (managed via FVM - see `.fvmrc`)
- **Dart SDK**: >=3.10.0

### Technology Stack

| Component | Technology |
|-----------|------------|
| State Management | GetX |
| Networking | Dio with HTTP/2 adapter (`dio_http2_adapter`) |
| Local Storage | Hive |
| Image Caching | `cached_network_image` |
| Video Player | Custom native plugin (ExoPlayer on Android, AVPlayer on iOS) |
| gRPC/Protobuf | `protobuf` (generated files in `lib/grpc/`) |
| WebView | `flutter_inappwebview` |
| Dynamic Theming | `dynamic_color` (Material 3) |
| Logging | `logger` + `catcher_2` for error reporting |

---

## Build Commands

> **Note**: This project uses **FVM** (Flutter Version Management). Use `fvm flutter` instead of `flutter` if FVM is installed.

### Development

```bash
# Install dependencies
flutter pub get

# Run app in debug mode
flutter run

# Analyze code
flutter analyze

# Format code (preserves trailing commas per analysis_options.yaml)
dart format .

# Generate code (if using build_runner)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Release Builds

```bash
# Build Android APK (split per ABI)
flutter build apk --release --split-per-abi

# Build Android APK (single)
flutter build apk --release

# Build iOS
flutter build ios --release

# Build with release configuration (used in CI)
flutter build apk --release --split-per-abi --dart-define-from-file=pili_release.json
```

### Build Configuration

The project uses a PowerShell script (`lib/scripts/build.ps1`) to set build-time environment variables:
- `pili.name` - Version name
- `pili.code` - Version code (git commit count)
- `pili.hash` - Git commit hash
- `pili.time` - Build timestamp

These are accessed via `BuildConfig` class in `lib/build_config.dart`.

---

## Project Structure

```
lib/
├── build_config.dart          # Build-time configuration constants
├── main.dart                  # App entry point, theme setup, initialization
├── common/                    # Shared widgets, constants, skeleton screens, animations
│   ├── constants.dart         # App constants, API keys, style values
│   ├── skeleton/              # Loading skeleton widgets
│   └── widgets/               # Reusable UI components
│       ├── animation/         # Custom animations
│       ├── appbar/            # AppBar components
│       ├── button/            # Button widgets
│       ├── dialog/            # Dialog components
│       ├── effects/           # Visual effects
│       ├── flutter/           # Custom Flutter widget overrides
│       ├── gesture/           # Gesture recognizers
│       ├── image/             # Image widgets (NetworkImgLayer)
│       ├── image_viewer/      # Image viewing components
│       ├── interactions/      # Interactive widgets
│       ├── loading/           # Loading indicators
│       ├── player/            # Player-related widgets
│       ├── progress_bar/      # Progress indicators
│       ├── refresh/           # Pull-to-refresh
│       ├── scroll/            # Scroll behaviors
│       ├── skeleton/          # Skeleton screens
│       ├── stat/              # Statistics displays
│       ├── transition/        # Page transitions
│       └── video_card/        # Video card widgets
├── grpc/                      # Protobuf generated files (DO NOT MODIFY MANUALLY)
│   ├── audio.dart             # gRPC audio utilities
│   ├── dm.dart                # Danmaku gRPC
│   ├── dyn.dart               # Dynamic feed gRPC
│   ├── im.dart                # Instant message gRPC
│   ├── reply.dart             # Comment reply gRPC
│   ├── space.dart             # User space gRPC
│   ├── url.dart               # URL utilities
│   ├── view.dart              # Video view gRPC
│   └── bilibili/              # Generated protobuf classes
├── http/                      # API layer
│   ├── api.dart               # API endpoint definitions
│   ├── constants.dart         # HTTP constants, base URLs
│   ├── danmaku.dart           # Danmaku API
│   ├── danmaku_block.dart     # Danmaku block API
│   ├── download.dart          # Download API
│   ├── dynamics.dart          # Dynamic feed API
│   ├── fan.dart               # Fan/follower API
│   ├── fav.dart               # Favorites API
│   ├── follow.dart            # Following API
│   ├── init.dart              # Dio initialization, Request class
│   ├── live.dart              # Live streaming API
│   ├── loading_state.dart     # Loading state handling
│   ├── login.dart             # Login API
│   ├── match.dart             # Match/game API
│   ├── member.dart            # Member/user API
│   ├── msg.dart               # Message API
│   ├── music.dart             # Music API
│   ├── pgc.dart               # Professional generated content API
│   ├── reply.dart             # Comment reply API
│   ├── retry_interceptor.dart # Retry logic for requests
│   ├── search.dart            # Search API
│   ├── sponsor_block.dart     # SponsorBlock API
│   ├── user.dart              # User API
│   ├── validate.dart          # Validation API
│   └── video.dart             # Video API
├── models_new/                # NEW data models (preferred for new code)
│   ├── account_myinfo/        # Account info models
│   ├── article/               # Article models
│   ├── common/                # Common/shared models
│   ├── danmaku/               # Danmaku models
│   ├── download/              # Download models
│   ├── dynamic/               # Dynamic feed models
│   ├── emote/                 # Emote models
│   ├── fav/                   # Favorites models
│   ├── history/               # Watch history models
│   ├── home/                  # Home page models
│   ├── live/                  # Live streaming models
│   ├── login/                 # Login models
│   ├── member/                # Member models
│   ├── msg/                   # Message models
│   ├── pgc/                   # PGC models
│   ├── reply/                 # Comment reply models
│   ├── search/                # Search models
│   ├── space/                 # User space models
│   ├── sponsor_block/         # SponsorBlock models
│   ├── triple/                # Like/coin/favorite triple action
│   ├── upload_bfs/            # Upload models
│   ├── user/                  # User models
│   └── video/                 # Video models
├── models/                    # LEGACY models (avoid adding new code here)
├── pages/                     # Feature modules (View + Controller pattern)
│   ├── home/                  # Home page (recommendations)
│   ├── hot/                   # Hot/trending videos
│   ├── video/                 # Video detail page
│   ├── search/                # Search functionality
│   ├── live_room/             # Live streaming room
│   ├── dynamics*/             # Dynamic feed pages
│   ├── fav*/                  # Favorites pages
│   ├── follow*/               # Following pages
│   ├── member*/               # User profile pages
│   ├── setting/               # Settings pages
│   └── ...                    # Many more feature pages
├── plugin/                    # Custom plugins
│   ├── native_player/         # Native video player plugin interface
│   │   ├── native_player.dart
│   │   └── native_player_value.dart
│   └── pl_player/             # Flutter player UI and controller
│       ├── controller.dart
│       ├── models/            # Player models (data_source, play_status, etc.)
│       ├── utils/             # Player utilities
│       ├── view.dart
│       └── widgets/           # Player UI widgets
├── router/                    # GetX route definitions
│   └── app_pages.dart         # All route definitions
├── scripts/                   # Build scripts and patches
│   ├── build.ps1              # PowerShell build script
│   ├── bottom_sheet_patch.diff    # Flutter framework patch
│   └── modal-barrier-patch.diff   # Flutter framework patch
├── services/                  # Global services (GetX services)
│   ├── account_service.dart   # Account management service
│   ├── audio_handler.dart     # Audio playback handler
│   ├── audio_session.dart     # Audio session management
│   ├── battery_service.dart   # Battery monitoring (for pure black theme)
│   ├── connection_warmup_service.dart  # HTTP connection warmup
│   ├── download/              # Download service directory
│   ├── haptic_service.dart    # Haptic feedback
│   ├── logger.dart            # Global logger instance
│   ├── service_locator.dart   # Service locator setup
│   └── shutdown_timer_service.dart  # Auto-shutdown timer
├── tcp/                       # TCP/Protobuf streaming
└── utils/                     # Utility classes
    ├── accounts/              # Account management utilities
    ├── app_scheme.dart        # URL scheme handling
    ├── app_sign.dart          # API signature utilities
    ├── cache_manager.dart     # Cache management
    ├── danmaku_utils.dart     # Danmaku utilities
    ├── date_utils.dart        # Date formatting
    ├── duration_utils.dart    # Duration formatting
    ├── em.dart                # EM (likely emoji) utilities
    ├── extension/             # Dart extension methods
    ├── fav_utils.dart         # Favorites utilities
    ├── feed_back.dart         # Haptic feedback utilities
    ├── global_data.dart       # Global data store
    ├── grid.dart              # Grid layout utilities
    ├── id_utils.dart          # ID conversion utilities (av/BV)
    ├── image_utils.dart       # Image processing
    ├── json_file_handler.dart # JSON file operations
    ├── login_utils.dart       # Login utilities
    ├── num_utils.dart         # Number formatting
    ├── page_utils.dart        # Page navigation utilities
    ├── path_utils.dart        # Path utilities
    ├── permission_handler.dart# Permission handling
    ├── platform_utils.dart    # Platform detection
    ├── recommend_filter.dart  # Recommendation filtering
    ├── reply_utils.dart       # Comment reply utilities
    ├── request_utils.dart     # HTTP request utilities
    ├── storage.dart           # Key-value storage (Hive)
    ├── storage_key.dart       # Storage key constants
    ├── storage_pref.dart      # Preference helpers
    ├── theme_utils.dart       # Theme utilities
    ├── update.dart            # App update checking
    ├── url_utils.dart         # URL utilities
    ├── utils.dart             # General utilities
    ├── video_utils.dart       # Video utilities
    ├── waterfall.dart         # Waterfall layout
    └── wbi_sign.dart          # WBI signature utilities
```

---

## Code Style Guidelines

### Import Rules

**MANDATORY**: Always use **package imports**. Relative imports are strictly forbidden.

```dart
// ✅ CORRECT
import 'package:PiliPro/utils/storage.dart';
import 'package:PiliPro/pages/home/controller.dart';

// ❌ INCORRECT
import '../../utils/storage.dart';
import '../controller.dart';
```

**Import Order**:
1. Flutter/Dart SDK imports
2. Third-party package imports
3. Project imports (`package:PiliPro/...`)

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `video_player_controller.dart` |
| Classes | `PascalCase` | `HomeController`, `VideoDetailPage` |
| Variables/Methods | `camelCase` | `isLoading`, `fetchData()` |
| Private Members | `_` prefix | `_internalState` |
| Constants | `camelCase` or `PascalCase` | `apiBaseUrl`, `AppName` |

### State Management (GetX Pattern)

Each page in `lib/pages/` follows the **View + Controller** pattern:

```
lib/pages/my_feature/
├── controller.dart   # GetxController with state and business logic
└── view.dart         # StatelessWidget UI
```

**Controller Example**:
```dart
// lib/pages/my_feature/controller.dart
class MyFeatureController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxList<VideoItem> videoList = <VideoItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      // Fetch data
    } finally {
      isLoading.value = false;
    }
  }
}
```

**View Example**:
```dart
// lib/pages/my_feature/view.dart
class MyFeaturePage extends StatelessWidget {
  const MyFeaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MyFeatureController());
    return Scaffold(
      body: Obx(() => controller.isLoading.value 
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(controller)),
    );
  }
}
```

### Reactivity Guidelines

- Use `.obs` for reactive variables
- Wrap reactive UI in `Obx(() => ...)`
- Use `GetBuilder` for non-reactive state updates
- Use `Get.put()`, `Get.lazyPut()`, or `Get.putOrFind()` for dependency injection

---

## Networking & API

### Request Pattern

Always use the global `Request()` instance from `lib/http/init.dart`:

```dart
import 'package:PiliPro/http/init.dart';
import 'package:PiliPro/http/api.dart';

try {
  final res = await Request().get(Api.myEndpoint);
  if (res.data['code'] == 0) {
    // Success - parse data
    final data = res.data['data'];
  } else {
    // API error
    logger.w('API error: ${res.data['message']}');
  }
} catch (e) {
  // Network/Other error
  final errorMsg = await AccountManager.dioError(e as DioException);
  logger.e('Failed to fetch data', error: e);
}
```

### Error Handling

Dio exceptions must be passed to `AccountManager.dioError(e)` for standardized error messaging:

```dart
catch (e) {
  final errorMsg = await AccountManager.dioError(e as DioException);
  // errorMsg contains user-friendly error message
}
```

### Logging

Use the global `logger` from `lib/services/logger.dart`. **Never use `print()`**.

```dart
import 'package:PiliPro/services/logger.dart';

logger.d('Debug message');                    // Debug
logger.i('Info message');                     // Info
logger.w('Warning message');                  // Warning
logger.e('Error message', error: e, stackTrace: s);  // Error
```

---

## UI Guidelines

### Material 3

- Use Material 3 components
- Access theme colors via `Theme.of(context).colorScheme`
- Support dynamic theming on Android 12+

### Common Widgets

- **Network Images**: Always use `NetworkImgLayer` from `lib/common/widgets/image/network_img_layer.dart`
- **Loading**: Use `LoadingWidget` or `SkeletonScreen`
- **Dialogs**: Use utilities from `lib/common/widgets/dialog/dialog.dart`

### Formatting

- `dart format .` with `trailing_commas: preserve` (configured in `analysis_options.yaml`)
- The analyzer enforces many lints - check `analysis_options.yaml` for the full list

---

## Native Video Player

The app uses a **custom native video player plugin** (not `video_player` or `media_kit`):

- **Android**: ExoPlayer with Media3 (Kotlin)
- **iOS**: AVPlayer (Swift)
- **Flutter Interface**: `lib/plugin/native_player/native_player.dart`

**Communication**:
- MethodChannel: `com.pilipro/native_player`
- EventChannel for playback events

**Key Files**:
- `android/app/src/main/kotlin/com/video/pilipro/NativePlayerPlugin.kt`
- `ios/Runner/NativePlayerPlugin.swift`
- `lib/plugin/native_player/native_player.dart`

The player UI is in `lib/plugin/pl_player/` with custom controls, danmaku support, and gesture handling.

---

## Testing

**Current Status**: The project has **no active test suite**. There is no `test/` directory.

When adding tests in the future:
```bash
flutter test test/path_to_test.dart
```

---

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

### `build.yml`
- Triggered on PRs and manual dispatch
- Builds Android APKs split by ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
- Applies Flutter framework patches from `lib/scripts/`
- Can release to GitHub Releases

### `ios.yml`
- Called by `build.yml` for iOS builds
- Creates unsigned IPA for sideloading

### Flutter Patches

The CI applies custom patches to the Flutter framework:
- `lib/scripts/bottom_sheet_patch.diff` - Bottom sheet behavior modifications
- `lib/scripts/modal-barrier-patch.diff` - Modal barrier modifications

These patches are applied to the Flutter SDK during build.

---

## Dependencies

### Forked Dependencies

Many dependencies are forked to the maintainer's GitHub (`bggRGjQaUbCoE`):

```yaml
# In pubspec.yaml
dependencies:
  get:
    git:
      url: https://github.com/bggRGjQaUbCoE/getx.git
      ref: version_4.7.2
  
  extended_nested_scroll_view:
    git:
      url: https://github.com/bggRGjQaUbCoE/extended_nested_scroll_view.git
      ref: mod
  
  material_design_icons_flutter:
    git:
      url: https://github.com/bggRGjQaUbCoE/material_design_icons_flutter.git
      ref: const
  
  # ... many more
```

**Important**: Do not upgrade these dependencies blindly. The forks contain custom modifications.

### Dependency Overrides

Several packages are overridden in `pubspec.yaml`:
```yaml
dependency_overrides:
  screen_brightness_platform_interface: ^2.1.0
  path: ^1.9.1
  mime: ^2.0.0
  rxdart: ^0.28.0
  font_awesome_flutter: 10.9.0
```

---

## Important Notes

### API Usage

- Uses **unofficial BiliBili APIs** documented in [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- Respects rate limits
- Some features require login
- AppKey/AppSec are defined in `lib/common/constants.dart`

### gRPC/Protobuf

- gRPC is managed via protobuf
- Generated files are in `lib/grpc/`
- **DO NOT MODIFY MANUALLY** - regenerate from `.proto` source files if needed

### Storage

- Uses Hive for local storage
- Storage keys defined in `lib/utils/storage_key.dart`
- Preferences accessed via `lib/utils/storage_pref.dart`

### Security

- No sensitive data in code (API keys are public BiliBili keys)
- User credentials stored securely via platform mechanisms
- HTTPS only for network requests

### Performance

- HTTP/2 support for better performance (configurable)
- Connection warmup on app start
- Image caching enabled
- Lazy loading for lists

---

## Resources

- **API Documentation**: https://github.com/SocialSisterYi/bilibili-API-collect
- **Original Project**: https://github.com/guozhigq/pilipala
- **Upstream Project**: https://github.com/orz12/PiliPalaX
- **Flutter Docs**: https://docs.flutter.dev
- **GetX Docs**: https://chornthorn.github.io/getx-docs/
