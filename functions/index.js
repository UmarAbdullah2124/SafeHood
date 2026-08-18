const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const CELL_DEGREES = 0.045;
const POST_TOPIC_PREFIX = 'safehood_posts';

function computeGeoCell(latitude, longitude) {
  const latCell = Math.floor(latitude / CELL_DEGREES);
  const lonCell = Math.floor(longitude / CELL_DEGREES);
  return `${latCell}_${lonCell}`;
}

function postTopicForCell(geoCell) {
  return `${POST_TOPIC_PREFIX}_${geoCell}`;
}

exports.notifyNearbyOnPost = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data() || {};
    const postId = context.params.postId;

    const latitude = Number(post.latitude);
    const longitude = Number(post.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      console.warn('Post missing valid coordinates, skipping FCM', postId);
      return null;
    }

    const type = post.type === 'help' ? 'help' : 'alert';
    const isAlert = type === 'alert';
    const emergencyType = post.emergencyType || 'Emergency';
    const locationName = post.locationName || '';
    const description = (post.description || '').slice(0, 120);

    const geoCell = computeGeoCell(latitude, longitude);
    const topic = postTopicForCell(geoCell);

    const title = isAlert ? 'New Alert Nearby' : 'Help Request Nearby';
    const body = isAlert
      ? (locationName
          ? `${emergencyType} · ${locationName}`
          : description || emergencyType)
      : (description ||
          (locationName ? `Help needed · ${locationName}` : 'Someone nearby needs help'));

    try {
      await admin.messaging().send({
        topic,
        notification: { title, body },
        data: {
          type,
          postId,
          emergencyType,
          description,
          locationName,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: isAlert
              ? 'safehood_emergency_alerts_v2'
              : 'safehood_help_requests_v1',
            priority: 'max',
            sound: isAlert ? 'default' : undefined,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      console.log(`Sent ${type} notification to topic ${topic} for post ${postId}`);
    } catch (error) {
      console.error('Failed to send post notification', error);
    }

    return null;
  });
