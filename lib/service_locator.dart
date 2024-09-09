import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:video_meeting_room/services/approval_service.dart';
import 'services/api_service.dart';
import 'services/permission_service.dart';
import 'services/room_data_manage_service.dart';

final GetIt getIt = GetIt.instance;

void setup() {
  final String apiServiceUrl = dotenv.env['API_LOCAL_NODE_URL']! ;
  getIt.registerSingleton<ApiService>(ApiService(apiServiceUrl));
  getIt.registerSingleton<PermissionService>(PermissionService());
  getIt.registerSingleton<ApprovalService>(ApprovalService(apiServiceUrl));
  getIt.registerSingleton<RoomDataManageService>(RoomDataManageService(apiServiceUrl));
}
