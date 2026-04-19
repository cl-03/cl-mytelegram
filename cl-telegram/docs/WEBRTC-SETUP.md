# WebRTC Setup Guide for cl-telegram

This guide explains how to set up WebRTC for real-time audio/video communication in cl-telegram.

## Overview

cl-telegram uses WebRTC for peer-to-peer audio/video calls. The implementation consists of:

1. **CFFI bindings** to libwebrtc C library (`src/api/webrtc-ffi.lisp`)
2. **Call management** (`src/api/voip.lisp`)
3. **UI components** for calls (`src/ui/clog-components.lisp`)
4. **Integration tests** (`tests/integration-webrtc-tests.lisp`)

## Prerequisites

### System Requirements

- **OS**: Linux, macOS, or Windows 10+
- **RAM**: 4GB+ (8GB recommended for video calls)
- **Network**: Broadband connection with UDP support

### Required Libraries

#### 1. libwebrtc C Library

The core WebRTC implementation. You have several options:

**Option A: Build from source (Linux)**

```bash
# Install dependencies
sudo apt-get install build-essential libssl-dev libx11-dev libxext-dev \
                     libxfixes-dev libxi-dev libxrender-dev libxkbfile-dev \
                     libasound2-dev libpulse-dev libdbus-1-dev

# Clone libwebrtc
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=$PWD/depot_tools:$PATH

# Fetch libwebrtc
mkdir webrtc-src && cd webrtc-src
fetch --nohooks webrtc
gclient sync

# Build
gn gen out/Release
ninja -C out/Release

# Install
sudo cp out/Release/libwebrtc.so /usr/local/lib/
sudo cp -r webrtc/api/* /usr/local/include/webrtc/
```

**Option B: Use pre-built binaries**

For testing purposes, you can use a stub library:

```bash
# Linux
sudo apt-get install libwebrtc-dev

# macOS
brew install webrtc

# Windows
# Download from: https://github.com/webrtc-sdk/webrtc/releases
```

**Option C: Development mode (no libwebrtc)**

For development without actual streaming, the FFI bindings will gracefully degrade:

```lisp
;; WebRTC functions will return NIL but not crash
(cl-telegram/api:init-webrtc)
;; => NIL (library not found, but no error)
```

#### 2. STUN/TURN Servers

For NAT traversal, you need STUN servers (included by default) and optionally TURN servers:

**Default STUN servers (pre-configured):**
- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`

**Optional TURN server setup:**

```lisp
;; Configure TURN server
(cl-telegram/api:create-webrtc-peer-connection
 :use-turn t
 :turn-uri "turn:your-turn-server.com:3478"
 :turn-username "your-username"
 :turn-credential "your-password")
```

**Public TURN servers for testing:**
- OpenTURN: `turn:openrelay.metered.ca:443`
  - Username: `test`
  - Password: `test`

## Installation

### Step 1: Install Quicklisp Dependencies

```lisp
(ql:quickload :cffi)
(ql:quickload :bordeaux-threads)
```

### Step 2: Load cl-telegram

```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)
```

### Step 3: Initialize WebRTC

```lisp
;; Initialize WebRTC subsystem
(init-webrtc)
;; => T if successful, NIL if libwebrtc not found
```

### Step 4: Verify Installation

```lisp
;; Run WebRTC connection test
(test-webrtc-connection)
;; => (:SUCCESS T :STATE :NEW :MESSAGE "WebRTC connection test passed")
```

## Usage

### Making an Audio Call

```lisp
(use-package :cl-telegram/api)

;; Initialize VoIP
(init-voip)

;; Create call to user
(let ((call (create-call user-id :is-video nil)))
  (when call
    ;; Start WebRTC
    (multiple-value-bind (sdp-offer error)
        (start-webrtc-call (call-id call))
      (if error
          (format t "Error: ~A~%" error)
          ;; Send SDP offer via Telegram signaling
          (progn
            (format t "SDP Offer created (~D chars)~%" (length sdp-offer))
            ;; send-call-signaling would be called here
            ))))))
```

### Making a Video Call

```lisp
;; Create video call
(let ((call (create-call user-id :is-video t)))
  (when call
    ;; Start WebRTC with video
    (start-webrtc-call (call-id call) :is-video t)))
```

### Accepting a Call

```lisp
;; Receive SDP offer from signaling
(let ((remote-sdp "v=0...")) ; Received from remote peer
  (multiple-value-bind (sdp-answer error)
      (accept-webrtc-call call-id remote-sdp)
    (if error
        (format t "Error: ~A~%" error)
        ;; Send answer back via signaling
        (format t "Answer created (~D chars)~%" (length sdp-answer)))))
```

### Group Calls

```lisp
;; Create group call
(let ((group-call (create-group-call chat-id :is-video-chat t)))
  (when group-call
    ;; Join group call
    (join-group-call (group-call-id group-call))
    ;; Show group call UI
    (show-group-call-panel *clog-window* (group-call-id group-call))))
```

### Using Data Channels

```lisp
;; Create data channel
(multiple-value-bind (channel-id error)
    (create-webrtc-data-channel "signaling")
  (when channel-id
    ;; Send data
    (send-webrtc-data channel-id #(1 2 3 4 5))
    ;; Close when done
    (close-webrtc-data-channel channel-id)))
```

## CLOG UI Integration

### Call Controls

The CLOG UI provides visual call controls:

```lisp
;; Show call panel
(show-call-panel *clog-window* call-id)

;; Show group call panel
(show-group-call-panel *clog-window* group-call-id)
```

### Call Buttons

- **🎤 Mute**: Toggle microphone mute
- **📹 Video**: Toggle video camera
- **📞 End**: End call

### Group Call Features

- Participant grid view
- Individual mute/video controls
- Participant count display
- Leave call button

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `init-webrtc` | Initialize WebRTC subsystem |
| `shutdown-webrtc` | Shutdown WebRTC and cleanup |
| `create-webrtc-peer-connection` | Create peer connection |
| `close-webrtc-peer-connection` | Close peer connection |
| `create-webrtc-media-stream` | Create audio/video stream |
| `close-webrtc-media-stream` | Close media stream |
| `create-webrtc-offer` | Create SDP offer |
| `create-webrtc-answer` | Create SDP answer |
| `set-webrtc-remote-description` | Set remote SDP |
| `add-webrtc-ice-candidate` | Add ICE candidate |
| `create-webrtc-data-channel` | Create data channel |
| `send-webrtc-data` | Send data over channel |

### State Functions

| Function | Description |
|----------|-------------|
| `get-webrtc-state` | Get connection state |
| `get-webrtc-signaling-state` | Get signaling state |
| `webrtc-stats` | Get statistics |
| `get-pending-ice-candidates` | Get pending ICE candidates |

### Call Integration

| Function | Description |
|----------|-------------|
| `start-webrtc-call` | Start WebRTC for call |
| `accept-webrtc-call` | Accept WebRTC call |
| `add-webrtc-candidate-to-call` | Add ICE candidate to call |
| `show-call-panel` | Show call UI |
| `show-group-call-panel` | Show group call UI |

## Troubleshooting

### WebRTC Initialization Fails

**Symptom**: `(init-webrtc)` returns `NIL`

**Causes**:
1. libwebrtc not installed
2. Library not in system path
3. Wrong library version

**Solutions**:
```lisp
;; Check if library loads
(handler-case
    (cffi:load-foreign-library "libwebrtc.so")
  (error (e)
    (format t "Load error: ~A~%" e)))

;; Try different library names
#+linux (cffi:load-foreign-library "libwebrtc.so.1")
#+darwin (cffi:load-foreign-library "libwebrtc.dylib")
#+windows (cffi:load-foreign-library "webrtc.dll")
```

### No Audio/Video

**Symptom**: Call connects but no media

**Causes**:
1. Microphone/camera permissions
2. Wrong device selection
3. Codec mismatch

**Solutions**:
```lisp
;; Check device permissions
;; Linux: pactl list sources (audio), v4l2-ctl --list-devices (video)
;; macOS: System Preferences > Privacy
;; Windows: Settings > Privacy > Camera/Microphone

;; Specify device explicitly
(create-webrtc-media-stream
 :audio-device "alsa_input.pci-0000_00_1b.0.analog-stereo"
 :video-device "/dev/video0")
```

### Connection Fails

**Symptom**: Call stuck at "Connecting..."

**Causes**:
1. NAT/Firewall blocking
2. No STUN/TURN server
3. Network issues

**Solutions**:
```lisp
;; Use TURN server
(create-webrtc-peer-connection
 :use-turn t
 :turn-uri "turn:openrelay.metered.ca:443"
 :turn-username "test"
 :turn-credential "test")

;; Check connection state
(get-webrtc-state)
;; :new -> :connecting -> :connected
;; If stuck at :connecting, check firewall
```

### ICE Candidates Not Exchanged

**Symptom**: One-way or no audio/video

**Causes**:
1. Signaling not exchanging candidates
2. Candidates arriving too late

**Solutions**:
```lisp
;; Collect all candidates before sending
(loop while (< (length (get-pending-ice-candidates)) 3)
      do (sleep 0.1))

;; Send candidates immediately as they arrive
(push candidate *pending-candidates*)
(send-signaling :type :ice-candidate :candidate candidate)
```

## Testing

### Run Unit Tests

```lisp
(asdf:load-system :cl-telegram/tests)
(fiveam:run! 'integration-webrtc-tests)
```

### Manual Testing

```lisp
;; Test initialization
(test-webrtc-connection)

;; Get statistics
(webrtc-stats)

;; Test data channel
(create-webrtc-peer-connection)
(create-webrtc-data-channel "test")
(send-webrtc-data "test" #(1 2 3))
```

## Performance Optimization

### Bitrate Control

```lisp
;; Set custom bitrates
(create-webrtc-media-stream
 :audio-bitrate 128000  ; 128 kbps audio
 :video-bitrate 2000000 ; 2 Mbps video
 :video-width 1280
 :video-height 720
 :video-fps 30)
```

### Resolution Scaling

For better performance on slow networks:

```lisp
;; Lower resolution
(create-webrtc-media-stream
 :video-width 640
 :video-height 480
 :video-fps 15
 :video-bitrate 500000)
```

## Security Considerations

### DTLS Encryption

WebRTC uses DTLS-SRTP for encryption by default. All media is encrypted in transit.

### Certificate Management

For production use, configure custom certificates:

```lisp
;; Generate and store certificates
;; (Implementation depends on libwebrtc version)
```

## Resources

- [WebRTC Specification](https://www.w3.org/TR/webrtc/)
- [libwebrtc Documentation](https://webrtc.org/)
- [MDN WebRTC API](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)
- [STUN/TURN Setup Guide](https://gokul.kirubakaran.com/blog/2020/05/turn-server-setup/)

## Support

For issues or questions:
1. Check this guide's Troubleshooting section
2. Review libwebrtc documentation
3. Open an issue on the cl-telegram repository
