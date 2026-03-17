import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'package:intl/intl.dart';

enum AdminPage { dashboard, detailedReports, users, banned, reports, listings }

class AdminController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminPage _currentPage = AdminPage.dashboard;
  AdminPage get currentPage => _currentPage;

  int _detailedReportTabIndex = 0;
  int get detailedReportTabIndex => _detailedReportTabIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void navigateTo(AdminPage page, {int tabIndex = 0}) {
    _currentPage = page;
    _detailedReportTabIndex = tabIndex;
    notifyListeners();
  }

  Future<void> runAdminSafetySweep() async {
    try {
      final snapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'student')
          .where('meritScore', isLessThanOrEqualTo: 40)
          .where('isSuspended', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      final suspensionDate = Timestamp.fromDate(DateTime.now().add(const Duration(days: 5)));

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isSuspended': true,
          'suspensionEndDate': suspensionDate,
        });
      }

      await batch.commit();
    } catch (e) {
      print("Error during safety sweep: $e");
    }
  }

  Future<void> banUser(String userId, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': true,
        'banReason': reason,
        'bannedAt': Timestamp.now(),
        'suspensionEndDate': FieldValue.delete(),
      });
    } catch (e) {
      print("Error banning user: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> unbanUser(String userId, {int? currentMeritScore}) async {
    _isLoading = true;
    notifyListeners();
    try {
      Map<String, dynamic> updates = {
        'isSuspended': false,
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
        'suspensionEndDate': FieldValue.delete(),
      };

      if (currentMeritScore != null && currentMeritScore <= 40) {
        updates['meritScore'] = 50;
      }

      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      print("Error unbanning user: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

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

        Map<String, dynamic> updates = {'meritScore': newScore};

        if (newScore <= 40 && (userData['isSuspended'] == false || userData['isSuspended'] == null)) {
          updates['isSuspended'] = true;
          updates['suspensionEndDate'] = Timestamp.fromDate(DateTime.now().add(const Duration(days: 5)));
          updates['banReason'] = 'System: Merit dropped to $newScore due to Admin deduction';
          updates['bannedAt'] = Timestamp.now();
        }

        transaction.update(userRef, updates);

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
            updates['suspensionEndDate'] = FieldValue.delete();
          }

          if (deductMerit) {
            int currentScore = (userData != null && userData.containsKey('meritScore'))
                ? (userData['meritScore'] as num).toInt()
                : 100;
            int newScore = currentScore - 10;
            if (newScore < 0) newScore = 0;
            updates['meritScore'] = newScore;

            if (newScore <= 40 && !suspendUser) {
              updates['isSuspended'] = true;
              updates['suspensionEndDate'] = Timestamp.fromDate(DateTime.now().add(const Duration(days: 5)));
              updates['banReason'] = 'System: Merit dropped to $newScore due to Admin penalty';
              updates['bannedAt'] = Timestamp.now();
            }

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

  Future<void> exportUsersToCsv({
    required String roleFilter,
    required bool sortAlpha,
    required bool includeSuspendedCol,
  }) async {
    Query query = _firestore.collection('users');
    if (roleFilter != 'All') {
      query = query.where('role', isEqualTo: roleFilter.toLowerCase());
    }

    final snapshot = await query.get();

    List<Map<String, dynamic>> users = snapshot.docs.map((d) {
      var data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();

    if (sortAlpha) {
      users.sort((a, b) {
        String nameA = (a['name'] ?? a['businessName'] ?? '').toString().toLowerCase();
        String nameB = (b['name'] ?? b['businessName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });
    }

    List<List<dynamic>> rows = [];
    List<String> headers = ["ID", "Name/Business", "Email", "Role", "Joined Date", "Merit Score"];
    if (includeSuspendedCol) headers.add("Is Suspended");
    rows.add(headers);

    for (var data in users) {
      final role = data['role'] ?? 'Unknown';
      final name = role == 'merchant' ? data['businessName'] : data['name'];
      final joined = data['createdAt'] != null ? DateFormat('yyyy-MM-dd').format((data['createdAt'] as Timestamp).toDate()) : 'Unknown';

      List<dynamic> row = [
        data['id'],
        name ?? "Unknown",
        data['email'] ?? "",
        role,
        joined,
        data['meritScore'] ?? (role == 'student' ? 100 : 'N/A'),
      ];

      if (includeSuspendedCol) {
        row.add(data['isSuspended'] ?? false);
      }

      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "sharebite_users_export_${DateTime.now().millisecondsSinceEpoch}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}