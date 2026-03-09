import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminPage { dashboard, detailedReports, users, banned, reports, listings }

class AdminController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminPage _currentPage = AdminPage.dashboard;
  AdminPage get currentPage => _currentPage;

  int _detailedReportTabIndex = 0;
  int get detailedReportTabIndex => _detailedReportTabIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  //nav
  void navigateTo(AdminPage page, {int tabIndex = 0}) {
    _currentPage = page;
    _detailedReportTabIndex = tabIndex;
    notifyListeners();
  }

  //ban user
  Future<void> banUser(String userId, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': true,
        'banReason': reason,
        'bannedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Error banning user: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  //unban
  Future<void> unbanUser(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': false,
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
      });
    } catch (e) {
      print("Error unbanning user: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  //delete posted listing
  Future<void> deleteListing(String listingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.collection('listings').doc(listingId).delete();
    } catch (e) {
      print("Error deleting listing: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  //resolve report
  Future<void> resolveReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': Timestamp.now(),
      });
      notifyListeners();
    } catch (e) {
      print("Error resolving report: $e");
    }
  }

  Future<bool> adjustMeritPoints(String studentId, int points, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(studentId);
        DocumentSnapshot userSnap = await transaction.get(userRef);

        if (!userSnap.exists) throw Exception("User not found");

        final userData = userSnap.data() as Map<String, dynamic>;
        int currentScore = userData['meritScore'] ?? 100;
        int newScore = currentScore + points;

        if (newScore > 100) newScore = 100;
        if (newScore < 0) newScore = 0;

        transaction.update(userRef, {'meritScore': newScore});

        DocumentReference logRef = _firestore.collection('merit_logs').doc();
        transaction.set(logRef, {
          'studentId': studentId,
          'points': points,
          'reason': 'Admin: $reason',
          'timestamp': Timestamp.now(),
        });
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print("Error adjusting merit points: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  //moderator
  Future<bool> moderateContent({
    required String reportId,
    required String targetId,
    required String offenderId,
    required bool deleteContent,
    required bool suspendUser,
    required bool deductMerit,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference reportRef = _firestore.collection('reports').doc(reportId);

        DocumentReference? reviewRef;
        if (deleteContent && targetId.isNotEmpty) {
          reviewRef = _firestore.collection('reviews').doc(targetId);
        }

        DocumentReference? userRef;
        if (offenderId.isNotEmpty && (suspendUser || deductMerit)) {
          userRef = _firestore.collection('users').doc(offenderId);
        }

        DocumentSnapshot? reviewSnap;
        if (reviewRef != null) {
          reviewSnap = await transaction.get(reviewRef);
        }

        DocumentSnapshot? userSnap;
        if (userRef != null) {
          userSnap = await transaction.get(userRef);
        }

        transaction.update(reportRef, {
          'status': 'resolved',
          'resolution': 'Actions: Delete=$deleteContent, Ban=$suspendUser, Merit=$deductMerit',
          'resolvedAt': Timestamp.now(),
        });

        if (reviewRef != null && reviewSnap != null && reviewSnap.exists) {
          transaction.delete(reviewRef);
        }

        if (userRef != null && userSnap != null && userSnap.exists) {
          final userData = userSnap.data() as Map<String, dynamic>?;
          Map<String, dynamic> updates = {};

          if (suspendUser) {
            updates['isSuspended'] = true;
            updates['banReason'] = 'Violated community guidelines (Inappropriate Review)';
            updates['bannedAt'] = Timestamp.now();
          }

          if (deductMerit) {
            int currentScore = (userData != null && userData.containsKey('meritScore'))
                ? (userData['meritScore'] as num).toInt()
                : 100;
            int newScore = currentScore - 10;
            if (newScore < 0) newScore = 0;
            updates['meritScore'] = newScore;

            DocumentReference logRef = _firestore.collection('merit_logs').doc();
            transaction.set(logRef, {
              'studentId': offenderId,
              'points': -10,
              'reason': 'Admin Penalty (Inappropriate Behavior)',
              'timestamp': Timestamp.now(),
            });
          }

          if (updates.isNotEmpty) {
            transaction.update(userRef, updates);
          }
        }
      });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e, stack) {
      print("CRITICAL MODERATION ERROR: $e");
      print("Stack trace: $stack");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}