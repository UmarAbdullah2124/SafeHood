import 'package:flutter/material.dart';

class EmergencyType {
  final String name;
  final IconData icon;

  const EmergencyType(this.name, this.icon);

  static const List<EmergencyType> types = [
    EmergencyType('Medical', Icons.medical_services),
    EmergencyType('Theft / Robbery', Icons.security),
    EmergencyType('House / Building Fire', Icons.local_fire_department),
    EmergencyType('Accident in Street', Icons.car_crash),
    EmergencyType('Sewer Overflow', Icons.water_drop),
    EmergencyType('Earthquake', Icons.public),
  ];

  static EmergencyType? fromText(String text) {
    final lowerText = text.toLowerCase();
    for (var type in types) {
      if (lowerText.contains(type.name.toLowerCase())) {
        return type;
      }
    }
    return types.first;
  }
}