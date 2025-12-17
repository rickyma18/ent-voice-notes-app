import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application_state/auth_state_provider/auth_state_provider.dart';
import 'router_state/router_state_provider.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
    ref.listen(routerStateProvider, (_, __) => notifyListeners());
  }
}
