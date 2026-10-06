import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/tasks/v1.dart' as gtasks;
import 'package:http/http.dart' as http;

import 'google_tasks_repository.dart';
import 'task_repository.dart';

/// Represents an authenticated Google user.
@immutable
class GoogleAuthUser {
  const GoogleAuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Active Google authentication session providing user details and a
/// [TaskRepository] connected to Google Tasks.
class GoogleAuthSession {
  const GoogleAuthSession({required this.user, required this.taskRepository});

  final GoogleAuthUser user;
  final TaskRepository taskRepository;
}

/// Service interface for authenticating with Google and obtaining a
/// Google Tasks [TaskRepository].
abstract class GoogleAuthService {
  /// Attempts to silently restore a previously authenticated Google session.
  /// Returns `null` if no session is available or interactive sign-in is needed.
  Future<GoogleAuthSession?> restoreSession();

  /// Triggers an interactive Google Sign-In flow and authorizes Google Tasks
  /// scope access. Returns `null` if the user cancels the sign-in flow.
  Future<GoogleAuthSession?> signIn();

  /// Signs out the current user and releases any active API client resources.
  Future<void> signOut();
}

/// Production [GoogleAuthService] implementation using `google_sign_in` and
/// `googleapis`.
class GoogleSignInAuthService implements GoogleAuthService {
  GoogleSignInAuthService({
    this.clientId,
    this.serverClientId,
    this.taskListId = GoogleTasksRepository.defaultTaskListId,
  });

  /// OAuth 2.0 scopes required for reading and writing Google Tasks.
  static const List<String> scopes = <String>[gtasks.TasksApi.tasksScope];

  static Future<void>? _initializationFuture;

  final String? clientId;
  final String? serverClientId;
  final String taskListId;

  http.Client? _activeAuthClient;

  Future<void> _ensureInitialized() {
    const String envClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    const String envServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );

    final String? effectiveClientId =
        clientId ?? (envClientId.isNotEmpty ? envClientId : null);
    final String? effectiveServerClientId =
        serverClientId ??
        (envServerClientId.isNotEmpty ? envServerClientId : null);

    return _initializationFuture ??= GoogleSignIn.instance.initialize(
      clientId: effectiveClientId,
      serverClientId: effectiveServerClientId,
    );
  }

  @override
  Future<GoogleAuthSession?> restoreSession() async {
    try {
      await _ensureInitialized();
      final Future<GoogleSignInAccount?>? lightweightFuture = GoogleSignIn
          .instance
          .attemptLightweightAuthentication();
      if (lightweightFuture == null) {
        return null;
      }

      final GoogleSignInAccount? account = await lightweightFuture;
      if (account == null) {
        return null;
      }

      GoogleSignInClientAuthorization? authz = await account.authorizationClient
          .authorizationForScopes(scopes);
      if (authz == null &&
          !GoogleSignIn.instance.authorizationRequiresUserInteraction()) {
        authz = await account.authorizationClient.authorizeScopes(scopes);
      }
      if (authz == null) {
        return null;
      }

      return _createSession(account, authz);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<GoogleAuthSession?> signIn() async {
    await _ensureInitialized();
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: scopes);

      final GoogleSignInClientAuthorization authz =
          await account.authorizationClient.authorizationForScopes(scopes) ??
          await account.authorizationClient.authorizeScopes(scopes);

      return _createSession(account, authz);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _activeAuthClient?.close();
    _activeAuthClient = null;
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }

  GoogleAuthSession _createSession(
    GoogleSignInAccount account,
    GoogleSignInClientAuthorization authz,
  ) {
    _activeAuthClient?.close();
    final http.Client authClient = authz.authClient(scopes: scopes);
    _activeAuthClient = authClient;

    final gtasks.TasksApi tasksApi = gtasks.TasksApi(authClient);
    final GoogleTasksRepository repository = GoogleTasksRepository(
      tasksApi: tasksApi,
      taskListId: taskListId,
    );

    return GoogleAuthSession(
      user: GoogleAuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      ),
      taskRepository: repository,
    );
  }
}
