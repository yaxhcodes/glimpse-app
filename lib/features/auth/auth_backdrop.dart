import 'package:flutter/material.dart';

/// Soft color fields painted directly, without a full-screen blur layer.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.8, -0.85),
              radius: 1.2,
              colors: [Color(0xB37D987F), Color(0x457D987F), Color(0x007D987F)],
              stops: [0, 0.45, 1],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1, -1.05),
                radius: 1.1,
                colors: [
                  Color(0x80F3EEDC),
                  Color(0x29F3EEDC),
                  Color(0x00F3EEDC),
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
