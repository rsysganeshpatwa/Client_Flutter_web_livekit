# LiveKit Flutter Video Conference Application

This repository contains a **Flutter-based video conference application** powered by [LiveKit](https://livekit.io/). The app supports real-time video conferencing with customizable backgrounds and OCR (Optical Character Recognition) capabilities for document scanning.

## Features
- Real-time video conferencing powered by LiveKit.
- Customizable backgrounds and video filters (e.g., background blur).
- OCR integration for document capture and text extraction.

## Technologies
- **Frontend**: Flutter using the [LiveKit Flutter SDK](https://github.com/livekit/client-sdk-flutter).
- **Backend**: Node.js API for OCR and video conferencing features.
- **Deployment**: 
  - Frontend: Hosted on AWS S3 with CloudFront for distribution.
  - Backend: Deployed on AWS EC2 with Nginx for reverse proxy.

## Prerequisites

Before starting, ensure that you have the following installed and set up:

### 1. Flutter SDK Installation

Flutter is the main framework used for building the frontend of the application. To install Flutter:

#### macOS:
1. Install Homebrew if you don’t have it:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
