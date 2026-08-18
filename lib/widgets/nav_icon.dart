import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class NavIcon extends StatelessWidget {
  final String assetName;
  final String filledAssetName;
  final String label;
  final int index;
  final int selectedIndex;
  final Function(int) onTap;

  const NavIcon({
    super.key,
    required this.assetName,
    required this.filledAssetName,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedIndex == index;

    IconData iconData;
    IconData filledIconData;

    switch (label) {
      case 'Home':
        iconData = Icons.home_rounded;
        filledIconData = Icons.home_rounded;
        break;
      case 'Community':
        iconData = Icons.people;
        filledIconData = Icons.people;
        break;
      case 'Safebot':
        iconData = Icons.auto_awesome;
        filledIconData = Icons.auto_awesome;
        break;
      case 'Profile':
        iconData = Icons.person;
        filledIconData = Icons.person;
        break;
      default:
        iconData = Icons.circle_outlined;
        filledIconData = Icons.circle;
    }

    Color iconColor = isSelected ? AppColors.blue : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? filledIconData : iconData,
                color: iconColor,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }
}