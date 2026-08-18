import 'package:flutter/material.dart';
import '../utils/app_colors.dart';  // Add this import
import '../models/emergency_type.dart';

class EmergencyService {
  static EmergencyType parseEmergencyType(String text) {
    return EmergencyType.fromText(text) ?? EmergencyType.types.first;
  }

  static void showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.2),
                    shape: BoxShape.circle
                ),
                child: Icon(Icons.check_circle, color: AppColors.green, size: 50),
              ),
              SizedBox(height: 20),
              Text(
                'Alert is registered and sent!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Your alert has been successfully registered and sent to nearby responders.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}