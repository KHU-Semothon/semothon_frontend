import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역에서 프로필 이미지/닉네임 상태를 공유하는 싱글톤 서비스.
/// 마이페이지에서 변경하면 커뮤니티/게시물에도 즉시 반영됩니다.
class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const String _keyAvatarPath = 'profile_avatar_path';
  static const String _keyUseDefault = 'profile_use_default';
  static const String _keyNickname   = 'profile_nickname';

  /// null → 기본 프로필(asset 이미지), non-null → 사용자 지정 파일
  File? _avatarFile;
  bool _useDefault = true;
  String _nickname = '';

  File?   get avatarFile  => _avatarFile;
  bool    get useDefault  => _useDefault;
  String  get nickname    => _nickname;

  /// 앱 시작 시 저장된 값을 복원
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname   = prefs.getString(_keyNickname) ?? '';
    _useDefault = prefs.getBool(_keyUseDefault) ?? true;
    final path  = prefs.getString(_keyAvatarPath);
    if (!_useDefault && path != null && File(path).existsSync()) {
      _avatarFile = File(path);
    } else {
      _avatarFile = null;
    }
    notifyListeners();
  }

  /// 기본 프로필로 변경
  Future<void> setDefaultAvatar() async {
    _useDefault = true;
    _avatarFile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDefault, true);
    await prefs.remove(_keyAvatarPath);
    notifyListeners();
  }

  /// 사용자 지정 이미지 파일로 변경
  Future<void> setAvatarFile(File file) async {
    _useDefault = false;
    _avatarFile = file;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDefault, false);
    await prefs.setString(_keyAvatarPath, file.path);
    notifyListeners();
  }

  /// 닉네임 변경
  Future<void> setNickname(String name) async {
    _nickname = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, name);
    notifyListeners();
  }
}
