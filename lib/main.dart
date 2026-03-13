import 'dart:io';


import 'package:PiliPro/common/constants.dart';
import 'package:PiliPro/common/widgets/custom_toast.dart';
import 'package:PiliPro/common/widgets/scale_app.dart';
import 'package:PiliPro/http/init.dart';
import 'package:PiliPro/models_new/common/theme/theme_color_type.dart';
import 'package:PiliPro/router/app_pages.dart';
import 'package:PiliPro/services/account_service.dart';
import 'package:PiliPro/services/battery_service.dart';
import 'package:PiliPro/services/connection_warmup_service.dart';
import 'package:PiliPro/services/download/download_service.dart';
import 'package:PiliPro/services/service_locator.dart';
import 'package:PiliPro/utils/app_scheme.dart';
import 'package:PiliPro/utils/cache_manager.dart';

import 'package:PiliPro/utils/extension/iterable_ext.dart';
import 'package:PiliPro/utils/extension/theme_ext.dart';
import 'package:PiliPro/utils/json_file_handler.dart';
import 'package:PiliPro/utils/page_utils.dart';
import 'package:PiliPro/utils/path_utils.dart';
import 'package:PiliPro/utils/platform_utils.dart';
import 'package:PiliPro/utils/request_utils.dart';
import 'package:PiliPro/utils/storage.dart';
import 'package:PiliPro/utils/storage_key.dart';
import 'package:PiliPro/utils/storage_pref.dart';
import 'package:PiliPro/utils/theme_utils.dart';
import 'package:PiliPro/utils/utils.dart';
import 'package:catcher_2/catcher_2.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

WebViewEnvironment? webViewEnvironment;

Future<void> _initDownPath() async {
  if (Platform.isAndroid) {
    final externalStorageDirPath = (await getExternalStorageDirectory())?.path;
    downloadPath = externalStorageDirPath != null
        ? path.join(externalStorageDirPath, PathUtils.downloadDir)
        : defDownloadPath;
  } else {
    downloadPath = defDownloadPath;
  }
}

Future<void> _initTmpPath() async {
  tmpDirPath = (await getTemporaryDirectory()).path;
}

Future<void> _initAppPath() async {
  appSupportDirPath = (await getApplicationSupportDirectory()).path;
}

void main() async {
  ScaledWidgetsFlutterBinding.ensureInitialized();
  // Native player initialized via NativePlayerPlugin (no media_kit needed)
  await _initAppPath();
  try {
    await GStorage.init();
  } catch (e) {
    await Utils.copyText(e.toString());
    if (kDebugMode) debugPrint('GStorage init error: $e');
    exit(0);
  }
  ScaledWidgetsFlutterBinding.instance.scaleFactor = Pref.uiScale;
  await Future.wait([_initDownPath(), _initTmpPath()]);
  Get
    ..lazyPut(AccountService.new)
    ..lazyPut(DownloadService.new)
    ..lazyPut(BatteryService.new)
    ..lazyPut(PureBlackThemeController.new);
  HttpOverrides.global = _CustomHttpOverrides();

  CacheManager.autoClearCache();

  if (PlatformUtils.isMobile) {
    await Future.wait([
      SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.portraitUp,
          if (Pref.horizontalScreen) ...[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ],
      ),
      setupServiceLocator(),
    ]);
  }

  Request();
  Request.setCookie();
  RequestUtils.syncHistoryStatus();
  
  // 应用启动时进行 DNS 预解析和连接预热（不阻塞启动流程）
  if (Pref.enableHttp2) {
    Future.microtask(() async {
      await ConnectionWarmupService().preResolveDns();
      await ConnectionWarmupService().warmupConnections();
    });
    
    // 延迟预热消息系统连接，避免与核心 API 预热竞争资源
    Future.delayed(const Duration(seconds: 3), () async {
      await ConnectionWarmupService().warmupForMessage();
    });
  }

  SmartDialog.config.toast = SmartConfigToast(
    displayType: SmartToastType.onlyRefresh,
  );

  if (PlatformUtils.isMobile) {
    PiliScheme.init();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    if (Platform.isAndroid) {
      FlutterDisplayMode.supported.then((mode) {
        final String? storageDisplay = GStorage.setting.get(
          SettingBoxKey.displayMode,
        );
        DisplayMode? displayMode;
        if (storageDisplay != null) {
          displayMode = mode.firstWhereOrNull(
            (e) => e.toString() == storageDisplay,
          );
        }
        FlutterDisplayMode.setPreferredMode(displayMode ?? DisplayMode.auto);
      });
    }
  }

  if (Pref.dynamicColor) {
    await MyApp.initPlatformState();
  }

  if (Pref.enableLog) {
    // 异常捕获 logo记录
    final fileHandler = await JsonFileHandler.init();
    final Catcher2Options debugConfig = Catcher2Options(
      SilentReportMode(),
      [
        ?fileHandler,
        ConsoleHandler(
          enableDeviceParameters: false,
          enableApplicationParameters: false,
          enableCustomParameters: false,
        ),
      ],
    );

    final Catcher2Options releaseConfig = Catcher2Options(
      SilentReportMode(),
      [
        ?fileHandler,
        ConsoleHandler(enableCustomParameters: false),
      ],
    );

    Catcher2(
      debugConfig: debugConfig,
      releaseConfig: releaseConfig,
      rootWidget: const MyApp(),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ColorScheme? _light, _dark;

  static ThemeData? darkThemeData;


  @override
  Widget build(BuildContext context) {
    final dynamicColor = Pref.dynamicColor && _light != null && _dark != null;
    late final brandColor = colorThemeTypes[Pref.customColor].color;
    late final variant = Pref.schemeVariant;

    // 监听纯黑主题控制器，支持省电模式自动切换
    return GetBuilder<PureBlackThemeController>(
      builder: (pureBlackController) {
        return GetMaterialApp(
          title: Constants.appName,
          theme: ThemeUtils.getThemeData(
            colorScheme: dynamicColor
                ? _light!
                : brandColor.asColorSchemeSeed(variant, .light),
            isDynamic: dynamicColor,
          ),
          darkTheme: ThemeUtils.getThemeData(
            isDark: true,
            colorScheme: dynamicColor
                ? _dark!
                : brandColor.asColorSchemeSeed(variant, .dark),
            isDynamic: dynamicColor,
            usePureBlack: pureBlackController.effectivePureBlack,
          ),
          themeMode: Pref.themeMode,
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          locale: const Locale("zh", "CN"),
          fallbackLocale: const Locale("zh", "CN"),
          supportedLocales: const [Locale("zh", "CN"), Locale("en", "US")],
          initialRoute: '/',
          getPages: Routes.getPages,
          defaultTransition: Transition.native,
          builder: FlutterSmartDialog.init(
            toastBuilder: (msg) => CustomToast(msg: msg),
            loadingBuilder: (msg) => LoadingWidget(msg: msg),
            builder: _builder,
          ),
          navigatorObservers: [
            PageUtils.routeObserver,
            FlutterSmartDialog.observer,
          ],
          scrollBehavior: null,
        );
      },
    );
  }

  static Widget _builder(BuildContext context, Widget? child) {
    final uiScale = Pref.uiScale;
    final mediaQuery = MediaQuery.of(context);
    final textScaler = TextScaler.linear(Pref.defaultTextScale);
    if (uiScale != 1.0) {
      child = MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: textScaler,
          size: mediaQuery.size / uiScale,
          padding: mediaQuery.padding / uiScale,
          viewInsets: mediaQuery.viewInsets / uiScale,
          viewPadding: mediaQuery.viewPadding / uiScale,
          devicePixelRatio: mediaQuery.devicePixelRatio * uiScale,
        ),
        child: child!,
      );
    } else {
      child = MediaQuery(
        data: mediaQuery.copyWith(textScaler: textScaler),
        child: child!,
      );
    }
    return child;
  }

  /// from [DynamicColorBuilderState.initPlatformState]
  static Future<bool> initPlatformState() async {
    if (_light != null || _dark != null) return true;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();

      if (corePalette != null) {
        if (kDebugMode) {
          debugPrint('dynamic_color: Core palette detected.');
        }
        _light = corePalette.toColorScheme();
        _dark = corePalette.toColorScheme(brightness: Brightness.dark);
        return true;
      }
    } on PlatformException {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain core palette.');
      }
    }

    try {
      final Color? accentColor = await DynamicColorPlugin.getAccentColor();

      if (accentColor != null) {
        if (kDebugMode) {
          debugPrint('dynamic_color: Accent color detected.');
        }
        final variant = Pref.schemeVariant;
        _light = accentColor.asColorSchemeSeed(variant, .light);
        _dark = accentColor.asColorSchemeSeed(variant, .dark);
        return true;
      }
    } on PlatformException {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain accent color.');
      }
    }
    if (kDebugMode) {
      debugPrint('dynamic_color: Dynamic color not detected on this device.');
    }
    GStorage.setting.put(SettingBoxKey.dynamicColor, false);
    return false;
  }
}

class _CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context)
      // 每个主机最大连接数，提高并发性能
      ..maxConnectionsPerHost = 32
      // 连接空闲超时时间
      ..idleTimeout = const Duration(seconds: 30);
    
    if (kDebugMode || Pref.badCertificateCallback) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }
}
