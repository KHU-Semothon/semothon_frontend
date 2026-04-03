import 'dart:io';
import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';

/// 앱 어디서나 사용할 수 있는 프로필 아바타 위젯.
/// UserProfileService를 구독해 프로필 변경 시 자동으로 갱신됩니다.
class UserAvatar extends StatelessWidget {
  final double radius;
  final Color backgroundColor;

  const UserAvatar({
    super.key,
    this.radius = 20,
    this.backgroundColor = const Color(0xFFD0D0D0),
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserProfileService(),
      builder: (context, _) {
        final svc = UserProfileService();
        return buildAvatar(
          avatarFile: svc.avatarFile,
          useDefault: svc.useDefault,
          radius: radius,
          backgroundColor: backgroundColor,
        );
      },
    );
  }

  /// 외부에서 static으로 사용 가능한 아바타 빌더
  static Widget buildAvatar({
    required File? avatarFile,
    required bool useDefault,
    double radius = 20,
    Color backgroundColor = const Color(0xFFD0D0D0),
  }) {
    ImageProvider? image;

    if (!useDefault && avatarFile != null && avatarFile.existsSync()) {
      image = FileImage(avatarFile);
    } else {
      // 기본 프로필: asset 이미지 (원형으로 표시됨)
      image = const AssetImage('assets/images/default_profile.png');
    }

    // 기본 프로필 사진일 경우 배경을 흰색으로 하여 이미지가 돋보이게 함
    final bgColor = (!useDefault && avatarFile != null) ? backgroundColor : Colors.white;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: ClipOval(
        child: Image(
          image: image!,
          fit: BoxFit.cover, // 혹은 필요에 따라 BoxFit.contain
        ),
      ),
    );
  }
}
