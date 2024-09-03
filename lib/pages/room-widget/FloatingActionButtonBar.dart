import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:video_meeting_room/models/role.dart';

class FloatingActionButtonBar extends StatelessWidget {
  final String localParticipantRole;
  final bool isMobile;
  final BuildContext context;
  final Future<void> Function(BuildContext) copyInviteLinkToClipboard;
  final Future<void> Function(BuildContext) showParticipantSelectionDialog;
  final VoidCallback openEndDrawer;
  final bool isScreenShare;
  final bool isScreenShareMode;
  final VoidCallback toggleViewMode;

  FloatingActionButtonBar({
    required this.localParticipantRole,
    required this.isMobile,
    required this.context,
    required this.copyInviteLinkToClipboard,
    required this.showParticipantSelectionDialog,
    required this.openEndDrawer,
    required this.isScreenShare,
    required this.toggleViewMode,
    required this.isScreenShareMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isScreenShare)
          FloatingActionButton(
            onPressed: toggleViewMode,
            child: Icon(isScreenShareMode ? Icons.grid_on : Icons.fullscreen),
            tooltip: isScreenShareMode ? 'View All' : 'View Shared Screen Only',
          ),
        SizedBox(height: 16),
        if (localParticipantRole == Role.admin.toString())
          FloatingActionButton(
            onPressed: () => copyInviteLinkToClipboard(context),
            child: Icon(Icons.link),
            tooltip: 'Copy invite link',
          ),
        SizedBox(height: 16),
        if (localParticipantRole == Role.admin.toString())
          FloatingActionButton(
            onPressed: () {
              if (isMobile) {
                showParticipantSelectionDialog(context);
              } else {
                openEndDrawer();
              }
            },
            child: Icon(Icons.people),
            tooltip: 'Manage Participants',
          ),
      ],
    );
  }
}
