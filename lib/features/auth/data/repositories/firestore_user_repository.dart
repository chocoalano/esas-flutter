import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/config/env.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../services/firebase_identity_service.dart';

/// The `users/{uid}` document in Firestore: one per Google account that has
/// signed in.
///
/// This is the first thing ESAS keeps in Firestore, and deliberately a small
/// one. The employee record, attendance and permits stay on the ESAS server;
/// this document exists so data that moves to Firestore later has an owner to
/// hang from, keyed by the same `uid` the security rules see as
/// `request.auth.uid`.
///
/// `lastTenant` is written by the client and is therefore only a hint. Nothing
/// may grant access because of it. When Firestore starts holding workspace
/// data, the workspace has to come from a custom claim set by the server — see
/// `firestore.rules`.
class FirestoreUserRepository {
  FirestoreUserRepository({
    required TenantContext tenantContext,
    FirebaseFirestore? firestore,
  }) : _tenant = tenantContext,
       _firestore =
           firestore ??
           FirebaseFirestore.instanceFor(
             app: Firebase.app(),
             databaseId: Env.firestoreDatabase,
           );

  final TenantContext _tenant;
  final FirebaseFirestore _firestore;

  static const String collection = 'users';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(collection).doc(uid);

  /// Create the document on first sign-in, refresh it on every one after.
  ///
  /// A transaction rather than `set(merge: true)`, because `createdAt` must be
  /// written exactly once and the rules refuse any update that changes it. A
  /// plain `update()` would not do either: on a document that does not exist
  /// yet the rules see an update with no `resource`, and the answer is
  /// `permission-denied` rather than the `not-found` the code would expect.
  Future<void> recordSignIn(GoogleIdentity identity) {
    final doc = _doc(identity.uid);

    final fields = <String, Object?>{
      'uid': identity.uid,
      'email': identity.email,
      'displayName': identity.displayName,
      'photoUrl': identity.photoUrl,
      'lastTenant': _tenant.tenant,
      'lastSignInAt': FieldValue.serverTimestamp(),
    };

    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(doc);

      if (snapshot.exists) {
        transaction.update(doc, fields);
      } else {
        transaction.set(doc, {
          ...fields,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
