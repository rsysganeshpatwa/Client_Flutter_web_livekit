import 'package:get_it/get_it.dart';
import 'package:video_meeting_room/app_config.dart';
import 'package:video_meeting_room/services/ai_voice_agent_service.dart';
import 'package:video_meeting_room/services/approval_service.dart';
import 'package:video_meeting_room/services/mom_agent_service.dart';
import 'package:video_meeting_room/services/textract_service.dart';
import 'services/api_service.dart';
import 'services/permission_service.dart';
import 'services/room_data_manage_service.dart';

final GetIt getIt = GetIt.instance;

void setup() {
  const String apiServiceUrl = AppConfig.apiNodeUrl; //dotenv.env['API_NODE_URL']! ;
  const String apiMomAgentUrl = AppConfig.apiMomAgent; //dotenv.env['API_MOM_AGENT']!;
  const String apiVoiceAgentUrl = AppConfig.apiVoiceAgent; //dotenv.env['API_VOICE_AGENT']!;
  getIt.registerSingleton<ApiService>(ApiService(apiServiceUrl));
  getIt.registerSingleton<PermissionService>(PermissionService());
  getIt.registerSingleton<ApprovalService>(ApprovalService(apiServiceUrl));
  getIt.registerSingleton<RoomDataManageService>(RoomDataManageService(apiServiceUrl));
  getIt.registerSingleton<TextractService>(TextractService(apiServiceUrl));
  getIt.registerSingleton<MomService>(MomService(apiMomAgentUrl));// For storing room names and their welcome messages
  getIt.registerSingleton<AIVoiceAgentService>(AIVoiceAgentService(baseUrl: apiVoiceAgentUrl)); // For AI voice agent interactions
  
}
