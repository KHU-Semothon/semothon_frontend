import 'package:flutter/material.dart';

class TravelExperienceScreen extends StatelessWidget {
  const TravelExperienceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Title
              const Text(
                '연동하기',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                '이 앱에 가입하려면 이메일을 입력하세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),
              // Airline Buttons
              _buildAirlineButton('아시아나 항공 연동하기'),
              const SizedBox(height: 12),
              _buildAirlineButton('제주항공 연동하기'),
              const SizedBox(height: 40),
              // Divider with "또는"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300], thickness: 0.8)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '또는',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300], thickness: 0.8)),
                ],
              ),
              const SizedBox(height: 40),
              // Photo Upload Section
              Text(
                '사진 업로드',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '사진 업로드 시에는 확인까지 2~3일이 소요될 수 있습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
              const Spacer(),
              // Home Indicator Area (Empty spacer)
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAirlineButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {}, // No functionality as requested
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF0F0F0),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
