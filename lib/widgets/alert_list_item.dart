import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../utils/app_colors.dart';

class AlertListItem extends StatelessWidget {
  final EmergencyPost post;
  final VoidCallback? onReport; // Only report callback
  final VoidCallback? onTap;

  const AlertListItem({
    super.key,
    required this.post,
    this.onReport,
    this.onTap,
  });

  Color getEmergencyColor() {
    switch (post.emergencyType.toLowerCase()) {
      case 'medical':
        return Colors.red;
      case 'fire':
        return Colors.orange;
      case 'theft / robbery':
        return Colors.purple;
      default:
        return AppColors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: getEmergencyColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.blue.withOpacity(0.2),
                      child: Text(
                        post.initials,  // This will show "JD" for John Doe
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      post.fullName,  // This will show "John Doe"
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatTime(post.timestamp),
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Emergency type badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getEmergencyColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                post.emergencyType.toUpperCase(),
                style: TextStyle(
                  color: getEmergencyColor(),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 8),

            // Description
            Text(
              post.description,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // Location
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey, size: 14),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.locationName,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Only Report button with count below (no like or comment)
            Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align to the right
              children: [
                // Report button with count below
                GestureDetector(
                  onTap: onReport,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "Report",
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        "${post.reportCount ?? 0}",
                        style: TextStyle(
                          color: Colors.orange.withOpacity(0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                if (post.isResolved == true) ...[
                  SizedBox(width: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RESOLVED',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}