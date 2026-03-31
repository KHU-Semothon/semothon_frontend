import 'package:flutter/material.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/list_item.dart';

class QaScreen extends StatelessWidget {
  const QaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> dummyQuestions = [
      "후쿠오카 지금 날씨 어떤가요?",
      "지금 시부야에 먹구름 개많아요",
      "OOO 갈만한 카페 추천 좀 해주세요",
      "여기 교통체증",
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomSearchBar(
                hintText: 'ㅋㅋㅋ',
                leftIcon: Icons.search,
                rightIcon: Icons.edit,
                onTap: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('최신순', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(
                    children: [
                      Text('기간', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[700], size: 18),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: ListView.separated(
                itemCount: 15,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                itemBuilder: (context, index) {
                  // Repeat the dummy questions for demonstration
                  final text = dummyQuestions[index % dummyQuestions.length];
                  return ListItem(text: text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
