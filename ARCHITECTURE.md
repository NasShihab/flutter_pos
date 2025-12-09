# Flutter POS - Architecture Documentation

## Overview

This document describes the architecture and design decisions for the Flutter POS Background Upload/Download Module.

## Architecture Pattern

The application follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (UI Screens, Widgets, User Interactions)               │
│  - upload_screen.dart                                    │
│  - download_screen.dart                                  │
│  - transfer_dashboard.dart                               │
│  - transfer_list_item.dart                               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   Provider Layer                         │
│  (State Management, Business Logic Coordination)        │
│  - transfer_provider.dart                                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    Domain Layer                          │
│  (Business Models, Entities)                            │
│  - transfer_state.dart                                   │
│  - TransferItem, TransferStatus, TransferType           │
└─────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                     Data Layer                           │
│  (Services, Data Sources, External APIs)                │
│  - api_service.dart                                      │
│  - file_transfer_service.dart                            │
│  - connectivity_service.dart                             │
│  - storage_service.dart                                  │
│  - permission_service.dart                               │
└─────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### 1. Presentation Layer

**Purpose**: Handle user interface and user interactions

**Components**:
- **Screens**: Full-page views (Upload, Download)
- **Widgets**: Reusable UI components (Dashboard, List Items)

**Responsibilities**:
- Render UI based on state
- Handle user input
- Display loading/error states
- Navigate between screens

**Rules**:
- No business logic
- No direct service calls
- Only communicate through Provider
- Stateless where possible

### 2. Provider Layer

**Purpose**: Manage application state and coordinate business logic

**Components**:
- `FileTransferProvider`: Main state manager

**Responsibilities**:
- Maintain transfer list
- Coordinate service calls
- Handle state transitions
- Manage notifications
- Persist state
- Auto-retry logic
- Network connectivity handling

**Rules**:
- Single source of truth for transfer state
- Notify listeners on state changes
- Handle errors gracefully
- No UI code

### 3. Domain Layer

**Purpose**: Define business entities and rules

**Components**:
- `TransferItem`: Transfer entity
- `TransferType`: Upload/Download enum
- `TransferStatus`: State enum

**Responsibilities**:
- Define data structures
- Provide serialization
- Business rules validation
- Helper methods

**Rules**:
- No dependencies on other layers
- Pure Dart (no Flutter imports)
- Immutable where possible

### 4. Data Layer

**Purpose**: Handle external data sources and services

**Components**:

#### ApiService
- OAuth2 authentication
- Token management
- HTTP client configuration
- Retry logic
- Error handling

#### FileTransferService
- File upload logic
- File download logic
- File validation
- Progress tracking
- URL validation

#### ConnectivityService
- Network status monitoring
- Connection type detection
- Real-time connectivity stream

#### StorageService
- Transfer state persistence
- History management
- SharedPreferences wrapper

#### PermissionService
- Runtime permission requests
- Permission status checks
- Android version handling

**Rules**:
- No UI dependencies
- Return data, not widgets
- Handle errors with exceptions
- Provide clear interfaces

## Data Flow

### Upload Flow

```
User selects file
       │
       ▼
UploadScreen validates file
       │
       ▼
FileTransferProvider.startUpload()
       │
       ├──> Check permissions
       │    (PermissionService)
       │
       ├──> Check network
       │    (ConnectivityService)
       │
       ├──> Validate file
       │    (FileTransferService)
       │
       ├──> Create TransferItem
       │    (Domain)
       │
       ├──> Add to transfers list
       │    (Provider state)
       │
       ├──> Persist state
       │    (StorageService)
       │
       └──> Perform upload
            │
            ├──> Get auth token
            │    (ApiService)
            │
            ├──> Upload file
            │    (FileTransferService)
            │
            ├──> Update progress
            │    (Provider)
            │
            ├──> Show notification
            │    (NotificationPlugin)
            │
            └──> Handle completion/error
                 │
                 ├──> Update status
                 ├──> Save to history
                 └──> Notify UI
```

### Download Flow

```
User enters URL
       │
       ▼
DownloadScreen validates URL
       │
       ▼
FileTransferProvider.startDownload()
       │
       ├──> Check permissions
       ├──> Check network
       ├──> Create TransferItem
       ├──> Add to transfers list
       ├──> Persist state
       │
       └──> Perform download
            │
            ├──> Get auth token (optional)
            ├──> Download file
            ├──> Update progress
            ├──> Show notification
            └──> Handle completion/error
```

### Pause/Resume Flow

```
User taps pause
       │
       ▼
FileTransferProvider.pauseTransfer()
       │
       ├──> Cancel CancelToken
       ├──> Update status to PAUSED
       ├──> Persist state
       └──> Notify UI

User taps resume
       │
       ▼
FileTransferProvider.resumeTransfer()
       │
       ├──> Check network
       ├──> Clear error
       ├──> Restart transfer
       │    (Note: Starts from 0%)
       └──> Notify UI
```

### Network Change Flow

```
Network disconnected
       │
       ▼
ConnectivityService detects change
       │
       ▼
FileTransferProvider receives event
       │
       ├──> Update isConnected flag
       ├──> Pause active transfers
       └──> Notify UI

Network reconnected
       │
       ▼
ConnectivityService detects change
       │
       ▼
FileTransferProvider receives event
       │
       ├──> Update isConnected flag
       ├──> Auto-resume paused transfers
       │    (only if paused due to network)
       └──> Notify UI
```

## State Management

### Provider Pattern

We use the **Provider** package for state management:

**Advantages**:
- Simple and intuitive
- Good performance
- Built-in to Flutter ecosystem
- Easy testing

**Implementation**:
```dart
// Provider setup in main.dart
ChangeNotifierProvider(
  create: (_) => FileTransferProvider(...)
)

// Consuming in widgets
Consumer<FileTransferProvider>(
  builder: (context, provider, child) {
    return Widget(...);
  }
)

// Calling methods
Provider.of<FileTransferProvider>(context, listen: false)
  .startUpload(file);
```

### State Structure

```dart
class FileTransferProvider extends ChangeNotifier {
  // State
  List<TransferItem> _transfers = [];
  bool _isConnected = true;
  
  // Getters (read-only access)
  List<TransferItem> get transfers => List.unmodifiable(_transfers);
  bool get isConnected => _isConnected;
  
  // Methods (state mutations)
  Future<void> startUpload(File file) { ... }
  void pauseTransfer(String id) { ... }
  void resumeTransfer(String id) { ... }
  
  // Notify listeners after state changes
  notifyListeners();
}
```

## Error Handling

### Error Hierarchy

```
Exception
    │
    ├── ApiException
    │   ├── AuthenticationException
    │   ├── NetworkException
    │   └── ServerException
    │
    └── FileTransferException
        ├── FileValidationException
        ├── PermissionException
        └── TransferException
```

### Error Handling Strategy

1. **Service Layer**: Throw specific exceptions
2. **Provider Layer**: Catch, log, update state
3. **UI Layer**: Display user-friendly messages

```dart
// Service throws
throw FileTransferException('File too large');

// Provider catches
try {
  await _service.uploadFile(...);
} on FileTransferException catch (e) {
  _updateStatus(id, TransferStatus.failed, error: e.message);
}

// UI displays
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(error))
);
```

## Persistence Strategy

### What to Persist

**Transfer State**:
- Active transfers (in-progress, paused, failed)
- Transfer metadata (id, type, path, url)
- Progress information
- Error messages
- Retry counts

**Transfer History**:
- Completed transfers (last 50)
- Timestamps
- File information

### Storage Mechanism

**SharedPreferences**:
- Simple key-value storage
- JSON serialization
- Synchronous read/write

```dart
// Save
await prefs.setString('transfers', jsonEncode(transfersJson));

// Load
final transfersString = prefs.getString('transfers');
final transfersJson = jsonDecode(transfersString);
```

### Persistence Timing

**Immediate**:
- Transfer added/removed
- Status changed
- Transfer completed

**Throttled**:
- Progress updates (every 5MB)
- Avoid excessive writes

## Notification System

### Notification Types

1. **Progress Notification**:
   - Ongoing, low priority
   - Shows progress bar
   - Updates frequently
   - Dismissible by pause/cancel

2. **Completion Notification**:
   - High priority
   - Persistent
   - Tappable (returns to app)
   - Auto-dismiss after tap

### Notification Channels

```dart
AndroidNotificationChannel(
  id: 'transfer_channel',
  name: 'File Transfers',
  description: 'Notifications for file uploads and downloads',
  importance: Importance.low, // or high for completion
)
```

### Notification Tap Handling

```dart
onDidReceiveNotificationResponse: (response) {
  // Navigate to specific transfer
  final transferId = response.payload;
  // Use navigation service or callback
}
```

## Network Resilience

### Retry Strategy

**Exponential Backoff**:
```
Attempt 1: Immediate
Attempt 2: Wait 1s
Attempt 3: Wait 2s
Attempt 4: Wait 4s
Max: 3 attempts
```

**Retry Conditions**:
- Network errors
- Timeout errors
- Server errors (5xx)
- Rate limiting (429)

**No Retry**:
- Client errors (4xx except 408, 429)
- Authentication errors
- File validation errors

### Connectivity Monitoring

```dart
ConnectivityService
    │
    ├──> Listen to connectivity changes
    ├──> Detect connection type
    ├──> Broadcast events
    │
    └──> FileTransferProvider
         │
         ├──> Update UI
         ├──> Pause transfers on disconnect
         └──> Resume transfers on reconnect
```

## Performance Considerations

### Memory Management

**Transfers List**:
- Keep only active transfers in memory
- Move completed to history
- Limit history to 50 items

**File Handling**:
- Stream-based upload/download
- No full file in memory
- Chunked processing

**State Updates**:
- Throttle progress updates
- Batch notifications
- Debounce persistence

### UI Optimization

**ListView**:
- Use `ListView.builder` for efficiency
- Reverse list (newest first)
- Limit visible items

**Notifications**:
- Update only on significant progress
- Use `onlyAlertOnce` flag
- Cancel on completion

## Testing Strategy

### Unit Tests

**Services**:
- Mock HTTP responses
- Test error handling
- Verify retry logic

**Provider**:
- Test state transitions
- Verify notifications
- Test persistence

**Domain**:
- Test serialization
- Verify business rules

### Widget Tests

**Screens**:
- Test UI rendering
- Verify user interactions
- Test error states

**Widgets**:
- Test progress display
- Verify action buttons
- Test swipe gestures

### Integration Tests

**End-to-End**:
- Upload flow
- Download flow
- Pause/Resume
- Network changes

## Security Considerations

### Authentication

- OAuth2 token-based
- Token refresh logic
- Secure token storage
- HTTPS only

### File Access

- Validate file paths
- Check permissions
- Scoped storage (Android 10+)
- Sandbox restrictions (iOS)

### Network

- HTTPS enforcement
- Certificate pinning (optional)
- Request signing (optional)

## Platform-Specific Notes

### Android

**Background Execution**:
- Foreground service for long transfers
- WorkManager for guaranteed execution
- Battery optimization handling

**Permissions**:
- Runtime permissions (Android 6+)
- Scoped storage (Android 10+)
- Granular media permissions (Android 13+)

**Notifications**:
- Notification channels (Android 8+)
- Runtime permission (Android 13+)

### iOS

**Background Execution**:
- URLSession background configuration
- Background fetch
- Limited background time

**Permissions**:
- Photo library access
- Notification permission
- App Transport Security

## Future Architecture Improvements

### Potential Enhancements

1. **Dependency Injection**:
   - Use GetIt or Injectable
   - Better testability
   - Cleaner initialization

2. **Repository Pattern**:
   - Abstract data sources
   - Easier to swap implementations
   - Better separation

3. **Use Cases/Interactors**:
   - Encapsulate business logic
   - Single responsibility
   - Easier testing

4. **Event Bus**:
   - Decouple components
   - Cross-cutting concerns
   - Better scalability

5. **State Management Alternatives**:
   - Riverpod (Provider evolution)
   - Bloc (event-driven)
   - GetX (reactive)

## Conclusion

This architecture provides:
- ✅ Clear separation of concerns
- ✅ Testable components
- ✅ Maintainable codebase
- ✅ Scalable structure
- ✅ Platform flexibility

The design balances simplicity with robustness, making it suitable for production use while remaining easy to understand and extend.
