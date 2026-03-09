import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../layout/admin_layout.dart';
import 'admin_login_page.dart';

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const AdminLayout();
        }

        return const AdminLoginPage();
      },
    );
  }
}