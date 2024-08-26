import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'services/api_service.dart';
import 'services/permission_service.dart';

final GetIt getIt = GetIt.instance;

void setup() {
  final String apiServiceUrl = dotenv.env['API_NODE_URL']! ;
  getIt.registerSingleton<ApiService>(ApiService(apiServiceUrl));
  getIt.registerSingleton<PermissionService>(PermissionService());
}
