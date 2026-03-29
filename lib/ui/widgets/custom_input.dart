import "package:flutter/material.dart";

class CustomInput extends StatelessWidget {
  const CustomInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.prefixIcon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: const Color(0xFF7F8A93), size: 18),
      ),
    );
  }
}
