import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../services/voice_alert_poster.dart';
import '../services/location_service.dart';

class QuickPostDialog extends StatefulWidget {
  final String intent;
  final String? emergencyType;
  final String? description;
  final String detectedText;

  const QuickPostDialog({
    super.key,
    required this.intent,
    this.emergencyType,
    this.description,
    required this.detectedText,
  });

  @override
  State<QuickPostDialog> createState() => _QuickPostDialogState();
}

class _QuickPostDialogState extends State<QuickPostDialog> {
  String? _selectedEmergencyType;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  final bool _useCurrentLocation = true;
  LatLng? _currentPosition;
  String? _locationName;

  final List<String> _emergencyTypes = [
    'Medical',
    'Theft / Robbery',
    'House / Building Fire',
    'Accident in Street',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEmergencyType = widget.emergencyType;
    _descriptionController.text = widget.description ?? '';
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await LocationService.getCurrentLocation();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _locationName = await LocationService.getAddressFromLatLng(_currentPosition!);
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _locationName = 'Unknown location';
      });
    }
  }

  Future<void> _submitPost() async {
    if (_selectedEmergencyType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select emergency type')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String description = _descriptionController.text.trim();
      if (description.isEmpty) {
        description = widget.intent == 'alert'
            ? 'Emergency alert triggered via voice: ${widget.detectedText}'
            : 'Help requested via voice: ${widget.detectedText}';
      }

      await VoiceAlertPoster.postAlert(
        intent: widget.intent,
        emergencyType: _selectedEmergencyType!,
        description: description,
        detectedText: widget.detectedText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.intent == 'alert'
                ? '🚨 Alert posted successfully!'
                : '🆘 Help request posted successfully!'),
            backgroundColor: widget.intent == 'alert' ? Colors.red : Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Icon(
              widget.intent == 'alert' ? Icons.warning_amber_rounded : Icons.help_outline,
              size: 50,
              color: widget.intent == 'alert' ? Colors.red : AppColors.blue,
            ),
            const SizedBox(height: 10),
            Text(
              widget.intent == 'alert' ? 'Post Emergency Alert' : 'Request Help',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Detected: "${widget.detectedText}"',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedEmergencyType,
              dropdownColor: AppColors.darkBg,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Emergency Type',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _emergencyTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedEmergencyType = value),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: AppColors.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationName ?? 'Getting location...',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.intent == 'alert' ? Colors.red : AppColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(
                      widget.intent == 'alert' ? 'Post Alert' : 'Request Help',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}