import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_defi_framework/komodo_defi_framework.dart';
import 'package:komodo_defi_local_auth/src/auth/auth_service.dart';
import 'package:komodo_defi_types/komodo_defi_types.dart';

class _FakeKdfOperations implements IKdfOperations {
  _FakeKdfOperations({required this.deleteWalletResponse});

  final Map<String, dynamic> deleteWalletResponse;

  @override
  String get operationsName => 'fake';

  @override
  Future<KdfStartupResult> kdfMain(
    Map<String, dynamic> startParams, {
    int? logLevel,
  }) async => KdfStartupResult.ok;

  @override
  Future<MainStatus> kdfMainStatus() async => MainStatus.rpcIsUp;

  @override
  Future<StopStatus> kdfStop() async => StopStatus.ok;

  @override
  Future<bool> isRunning() async => true;

  @override
  Future<String?> version() async => 'test-version';

  @override
  Future<Map<String, dynamic>> mm2Rpc(Map<String, dynamic> request) async {
    switch (request['method']) {
      case 'delete_wallet':
        return deleteWalletResponse;
      case 'stream::shutdown_signal::enable':
        return {
          'mmrpc': '2.0',
          'result': {'streamer_id': 'test-stream'},
        };
      default:
        return {'mmrpc': '2.0', 'result': <String, dynamic>{}};
    }
  }

  @override
  Future<void> validateSetup() async {}

  @override
  Future<bool> isAvailable(IKdfHostConfig hostConfig) async => true;

  @override
  void resetHttpClient() {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('KdfAuthService.deleteWallet', () {
    test(
      'maps WalletNotFound GeneralErrorResponse to AuthException.notFound',
      () async {
        final service = _createService({
          'mmrpc': '2.0',
          'result': {
            'details': {
              'error': 'Wallet not found',
              'error_type': 'WalletNotFound',
            },
          },
        });
        addTearDown(service.dispose);

        await expectLater(
          () => service.deleteWallet(walletName: 'missing', password: 'secret'),
          throwsA(
            isA<AuthException>().having(
              (error) => error.type,
              'type',
              AuthExceptionType.walletNotFound,
            ),
          ),
        );
      },
    );

    test(
      'maps CannotDeleteActiveWallet GeneralErrorResponse to auth error',
      () async {
        final service = _createService({
          'mmrpc': '2.0',
          'result': {
            'details': {
              'error': 'Cannot delete active wallet',
              'error_type': 'CannotDeleteActiveWallet',
            },
          },
        });
        addTearDown(service.dispose);

        await expectLater(
          () => service.deleteWallet(walletName: 'active', password: 'secret'),
          throwsA(
            isA<AuthException>()
                .having(
                  (error) => error.type,
                  'type',
                  AuthExceptionType.generalAuthError,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Cannot delete active wallet',
                ),
          ),
        );
      },
    );
  });
}

KdfAuthService _createService(Map<String, dynamic> deleteWalletResponse) {
  final hostConfig = LocalConfig(https: false, rpcPassword: 'rpc-pass');
  final framework = KomodoDefiFramework.createWithOperations(
    hostConfig: hostConfig,
    kdfOperations: _FakeKdfOperations(
      deleteWalletResponse: deleteWalletResponse,
    ),
  );

  return KdfAuthService(framework, hostConfig);
}
