import 'package:flutter/material.dart';

class GoodCard extends StatelessWidget {
  final String name;
  final bool selected;
  final bool faceDown;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const GoodCard({
    super.key,
    required this.name,
    this.selected = false,
    this.faceDown = false,
    this.onTap,
    this.width = 80,
    this.height = 110,
  });

  static const _cardColors = {
    'apple': Color(0xFF4CAF50),
    'cheese': Color(0xFFFFC107),
    'bread': Color(0xFF8D6E63),
    'chicken': Color(0xFFFFECB3),
    'pepper': Color(0xFFF44336),
    'silk': Color(0xFF9C27B0),
    'crossbow': Color(0xFF607D8B),
    'mead': Color(0xFFFF9800),
  };

  static final _cardIcons = <String, IconData>{
    'apple': Icons.apple,
    'cheese': Icons.pie_chart,
    'bread': Icons.bakery_dining,
    'chicken': Icons.egg,
    'pepper': Icons.local_fire_department,
    'silk': Icons.auto_awesome,
    'crossbow': Icons.gps_fixed,
    'mead': Icons.local_drink,
  };

  static bool isContraband(String name) =>
      name == 'pepper' || name == 'silk' || name == 'crossbow' || name == 'mead';

  @override
  Widget build(BuildContext context) {
    if (faceDown) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF5D4037),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown.shade800, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.question_mark, color: Colors.white54, size: 28),
          ),
        ),
      );
    }

    final color = _cardColors[name] ?? Colors.grey;
    final icon = _cardIcons[name] ?? Icons.help_outline;
    final contraband = isContraband(name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        transform: selected ? (Matrix4.identity()..translate(0.0, -8.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.blue : color,
            width: selected ? 3 : 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8)]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (contraband)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CONTRABAND',
                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                ),
              ),
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(
              name[0].toUpperCase() + name.substring(1),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
