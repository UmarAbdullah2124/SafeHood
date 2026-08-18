import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../utils/distance_utils.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  static Future<UserCredential> signInAnonymously() async {
    try {
      print('🔄 Signing in anonymously...');
      final result = await _auth.signInAnonymously();
      print('✅ Signed in: ${result.user?.uid}');
      return result;
    } catch (e) {
      print('❌ Sign in failed: $e');
      rethrow;
    }
  }

  static Future<String> createPost(EmergencyPost post) async {
    try {
      print('🔄 Creating post...');
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        await signInAnonymously();
        currentUser = _auth.currentUser;
      }

      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && (userDoc.data() as Map<String, dynamic>)['isBlocked'] == true) {
          throw Exception('Your account is blocked and cannot create posts.');
        }
      }

      DocumentReference docRef = await _firestore.collection('posts').add(post.toMap());
      print('✅ Post created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Create post failed: $e');
      rethrow;
    }
  }

  static Stream<List<EmergencyPost>> getPostsByTypeStream(String type) {
    print('🔄 Getting posts stream for type: $type');

    try {
      return _firestore
          .collection('posts')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .handleError((error) {
        print('❌ Stream error: $error');
        return Stream.error(error);
      })
          .map((snapshot) {
        print('📊 Received ${snapshot.docs.length} posts of type: $type');
        final posts = snapshot.docs.map((doc) {
          return EmergencyPost.fromMap(doc.id, doc.data());
        }).toList();
        return posts;
      });
    } catch (e) {
      print('❌ Error creating stream: $e');
      return Stream.error(e);
    }
  }

  static Future<void> votePost(String postId, bool isTrue) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to vote');
    }
    final uid = user.uid;

    try {
      DocumentReference postRef = _firestore.collection('posts').doc(postId);
      DocumentReference voteRef = postRef.collection('votes').doc(uid);

      await _firestore.runTransaction((transaction) async {
        // 1. Check if user already voted on this post
        DocumentSnapshot voteSnapshot = await transaction.get(voteRef);
        if (voteSnapshot.exists) {
          throw Exception('You have already voted on this post');
        }

        // 2. Get post data
        DocumentSnapshot postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) {
          throw Exception('Post not found');
        }

        String authorId = postSnapshot['userId'] ?? '';
        
        // Optional: Prevent users from voting on their own post
        if (authorId == uid) {
          throw Exception('You cannot vote on your own post');
        }

        int currentTrueVotes = postSnapshot['trueVotes'] ?? 0;
        int currentFakeVotes = postSnapshot['fakeVotes'] ?? 0;
        int currentReportCount = postSnapshot['reportCount'] ?? 0;
        String postType = postSnapshot['type'] ?? 'alert';

        if (isTrue) {
          currentTrueVotes += 1;
        } else {
          currentFakeVotes += 1;
        }

        // 3. Update post document
        transaction.update(postRef, {
          'trueVotes': currentTrueVotes,
          'fakeVotes': currentFakeVotes,
          'reportCount': currentReportCount + 1,
        });

        // 4. Create vote record to prevent multiple votes
        transaction.set(voteRef, {
          'isTrue': isTrue,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 5. Blocking logic
        if (authorId.isNotEmpty) {
          bool shouldBlock = false;
          
          if (postType == 'help') {
            // Help posts: Minimum 5 fake votes mandatory
            if (currentFakeVotes >= 5) {
              shouldBlock = true;
            }
          } else {
            // Alert posts (default): Minimum 3 fake votes mandatory
            if (currentFakeVotes >= 3) {
              shouldBlock = true;
            }
          }

          if (shouldBlock) {
            transaction.set(
              _firestore.collection('users').doc(authorId),
              {'isBlocked': true},
              SetOptions(merge: true),
            );
          }
        }
      });
    } catch (e) {
      print('Error voting on post: $e');
      rethrow;
    }
  }

  static Stream<List<EmergencyPost>> getNearbyPostsStream(
      String type,
      double currentLat,
      double currentLon,
      double radiusKm
      ) {
    print('🔄 Getting nearby posts within $radiusKm km');

    // Firestore can only do simple filters, so we fetch all posts in a rough area first
    // then filter precisely on client side

    // Approximate 1 degree latitude ≈ 111 km
    // So for 1km radius, we look for posts within ~0.009 degrees
    double latDelta = radiusKm / 111.0;
    double lonDelta = radiusKm / (111.0 * cos(currentLat * pi / 180));

    return _firestore
        .collection('posts')
        .where('type', isEqualTo: type)
        .where('latitude', isGreaterThanOrEqualTo: currentLat - latDelta)
        .where('latitude', isLessThanOrEqualTo: currentLat + latDelta)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      List<EmergencyPost> allPosts = snapshot.docs.map((doc) {
        return EmergencyPost.fromMap(doc.id, doc.data());
      }).toList();

      // Filter posts within exact radius
      List<EmergencyPost> nearbyPosts = allPosts.where((post) {
        double distance = DistanceUtils.calculateDistance(
            currentLat, currentLon,
            post.latitude, post.longitude
        );
        bool isNearby = distance <= radiusKm;
        print('Post ${post.id} distance: ${distance.toStringAsFixed(2)}km - ${isNearby ? "✅" : "❌"}');
        return isNearby;
      }).toList();

      print('📊 Found ${nearbyPosts.length} posts within $radiusKm km (out of ${allPosts.length} total)');
      return nearbyPosts;
    });
  }
}