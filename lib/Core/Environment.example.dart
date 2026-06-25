// Скопируйте этот файл в Environment.dart и заполните своими значениями
// cp lib/Core/Environment.example.dart lib/Core/Environment.dart

import 'package:flutter/foundation.dart';

class Environment {
  final String name;
  final String deeplinkUrl;
  final String linkDomain;
  final String iosBundleId;
  final String androidPackageName;
  final bool isProduction;
  final String googleIosClientId;
  final String googleAndroidClientId;
  final String googleServerClientId;
  final String googleIosClientIdPlain;
  final String googleServerClientIdPlain;
  final String googleOAuthCallbackScheme;
  final String deeplinkScheme;
  String grpcHost;
  int grpcPort;
  bool grpcSecure;
  String apiBaseUrl;
  String? otlpEndpoint;

  Environment._({
    required this.name,
    required this.deeplinkUrl,
    required this.linkDomain,
    required this.iosBundleId,
    required this.androidPackageName,
    required this.isProduction,
    required this.googleIosClientId,
    required this.googleAndroidClientId,
    required this.googleServerClientId,
    required this.googleIosClientIdPlain,
    required this.googleServerClientIdPlain,
    required this.googleOAuthCallbackScheme,
    required this.deeplinkScheme,
    required this.grpcHost,
    required this.grpcPort,
    required this.grpcSecure,
    required this.apiBaseUrl,
  });

  static late Environment _instance;

  static Environment get instance => _instance;

  static void initStaging() {
    _instance = Environment._(
      name: 'Staging',
      deeplinkUrl: 'https://YOUR_STAGING_DEEPLINK_URL',
      linkDomain: 'YOUR_STAGING_LINK_DOMAIN',
      iosBundleId: 'YOUR_DEV_IOS_BUNDLE_ID',
      androidPackageName: 'YOUR_DEV_ANDROID_PACKAGE_NAME',
      isProduction: false,
      googleIosClientId: 'YOUR_STAGING_IOS_CLIENT_ID.apps.googleusercontent.com',
      googleAndroidClientId: 'YOUR_STAGING_ANDROID_CLIENT_ID.apps.googleusercontent.com',
      googleServerClientId: 'YOUR_STAGING_SERVER_CLIENT_ID.apps.googleusercontent.com',
      googleIosClientIdPlain: 'YOUR_STAGING_IOS_CLIENT_ID',
      googleServerClientIdPlain: 'YOUR_STAGING_SERVER_CLIENT_ID',
      googleOAuthCallbackScheme: 'com.googleusercontent.apps.YOUR_STAGING_IOS_CLIENT_ID',
      deeplinkScheme: 'mind-staging',
      grpcHost: 'YOUR_STAGING_GRPC_HOST',
      grpcPort: 443,
      grpcSecure: true,
      apiBaseUrl: 'https://YOUR_STAGING_API_URL',
    );
    if (kDebugMode) overrideForDev();
  }

  static void overrideForDev() {
    _instance.grpcHost = 'YOUR_DEV_IP';
    _instance.grpcPort = 50051;
    _instance.grpcSecure = false;
    _instance.apiBaseUrl = 'http://YOUR_DEV_IP:3001';
    _instance.otlpEndpoint = 'http://YOUR_DEV_IP:3100/otlp/v1/logs';
  }

  static void initProd() {
    _instance = Environment._(
      name: 'Production',
      deeplinkUrl: 'https://YOUR_PROD_DEEPLINK_URL',
      linkDomain: 'YOUR_PROD_LINK_DOMAIN',
      iosBundleId: 'YOUR_PROD_IOS_BUNDLE_ID',
      androidPackageName: 'YOUR_PROD_ANDROID_PACKAGE_NAME',
      isProduction: true,
      googleIosClientId: 'YOUR_PROD_IOS_CLIENT_ID.apps.googleusercontent.com',
      googleAndroidClientId: 'YOUR_PROD_ANDROID_CLIENT_ID.apps.googleusercontent.com',
      googleServerClientId: 'YOUR_PROD_SERVER_CLIENT_ID.apps.googleusercontent.com',
      googleIosClientIdPlain: 'YOUR_PROD_IOS_CLIENT_ID',
      googleServerClientIdPlain: 'YOUR_PROD_SERVER_CLIENT_ID',
      googleOAuthCallbackScheme: 'com.googleusercontent.apps.YOUR_PROD_IOS_CLIENT_ID',
      deeplinkScheme: 'mind',
      grpcHost: 'YOUR_PROD_GRPC_HOST',
      grpcPort: 443,
      grpcSecure: true,
      apiBaseUrl: 'https://YOUR_PROD_API_URL',
    );
  }
}
