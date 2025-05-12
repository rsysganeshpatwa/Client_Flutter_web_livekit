// ignore_for_file: file_names

import 'package:flutter/material.dart';
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

  const FloatingActionButtonBar({super.key, 
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
            tooltip: isScreenShareMode ? 'View All' : 'View Shared Screen Only',
            child: Icon(isScreenShareMode ? Icons.grid_on : Icons.fullscreen),
          ),
        const SizedBox(height: 16),
        if (localParticipantRole == Role.admin.toString())
          FloatingActionButton(
            onPressed: () => copyInviteLinkToClipboard(context),
            tooltip: 'Copy invite link',
            child: const Icon(Icons.link),
          ),
        const SizedBox(height: 16),
        if (localParticipantRole == Role.admin.toString())
          FloatingActionButton(
            onPressed: () {
              if (isMobile) {
                showParticipantSelectionDialog(context);
              } else {
                openEndDrawer();
              }
            },
            tooltip: 'Manage Participants',
            child: const Icon(Icons.people),
          ),
      ],
    );
  }
}
