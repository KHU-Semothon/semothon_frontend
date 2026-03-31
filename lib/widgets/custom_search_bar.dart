import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final String hintText;
  final IconData leftIcon;
  final IconData? rightIcon;
  final VoidCallback? onTap;

  const CustomSearchBar({
    super.key,
    required this.hintText,
    required this.leftIcon,
    this.rightIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // ~0.05 opacity
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
               children: [
                 Icon(leftIcon, color: Colors.grey[600]),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Text(
                     hintText,
                     style: const TextStyle(
                       color: Colors.black,
                       fontSize: 15,
                     ),
                   ),
                 ),
                 if (rightIcon != null)
                   Icon(rightIcon, color: Colors.grey[600]),
               ],
            ),
          ),
        ),
      ),
    );
  }
}
