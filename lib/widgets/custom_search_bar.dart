import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final String hintText;
  final IconData leftIcon;
  final IconData? rightIcon;
  final VoidCallback? onTap;
  final VoidCallback? onRightIconTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final bool readOnly;
  final Color? backgroundColor;

  const CustomSearchBar({
    super.key,
    required this.hintText,
    required this.leftIcon,
    this.rightIcon,
    this.onTap,
    this.onRightIconTap,
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.readOnly = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFD9D9D9),
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
          onTap: readOnly ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
               children: [
                 Icon(leftIcon, color: Colors.grey[600]),
                 const SizedBox(width: 12),
                 Expanded(
                   child: readOnly
                     ? Text(
                         hintText,
                         style: const TextStyle(
                           color: Colors.black,
                           fontSize: 15,
                         ),
                       )
                     : TextField(
                         controller: controller,
                         readOnly: readOnly,
                         onChanged: onChanged,
                         onSubmitted: onSubmitted,
                         textInputAction: TextInputAction.search,
                         decoration: InputDecoration(
                           hintText: hintText,
                           border: InputBorder.none,
                           isDense: true,
                           contentPadding: EdgeInsets.zero,
                         ),
                         style: const TextStyle(
                           color: Colors.black,
                           fontSize: 16,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                 ),
                 if (rightIcon != null)
                   GestureDetector(
                     onTap: onRightIconTap,
                     child: Icon(rightIcon, color: Colors.grey[600]),
                   ),
               ],
            ),
          ),
        ),
      ),
    );
  }
}
