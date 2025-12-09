# Flutter POS - Background Upload/Download Module

A robust file transfer module for Flutter POS SAAS application demonstrating enterprise-grade upload/download capabilities with background support, network resilience, and comprehensive state management.

## 🚀 Features

### Core Functionality
- ✅ **Large File Support**: Upload/download files >50MB with progress tracking
- ✅ **Background Operation**: Transfers continue when app is minimized (with platform limitations)
- ✅ **Real-time Progress**: Live progress indicators with percentage and data transferred
- ✅ **System Notifications**: Persistent notifications with tap-to-return functionality
- ✅ **Pause & Resume**: Full control over transfer operations
- ✅ **Network Resilience**: Auto-retry on failure with exponential backoff
- ✅ **Connectivity Monitoring**: Real-time network status with auto-resume on reconnection
- ✅ **State Persistence**: Transfers survive app restarts
- ✅ **Global Dashboard**: Centralized view of all transfers from anywhere in the app

### Advanced Features
- 🔐 **Permission Handling**: Runtime permission requests for Android 13+
- 🔄 **Auto-Retry**: Intelligent retry logic with exponential backoff
- 📊 **Transfer History**: Persistent history of completed transfers
- 🎯 **File Validation**: Pre-upload validation for file size and type
- 🌐 **Network Awareness**: Different behavior based on WiFi/Mobile data
- 🎨 **Modern UI**: Material Design 3 with smooth animations
- 🔍 **Filter & Search**: Filter transfers by status
- 🗑️ **Swipe to Delete**: Intuitive gesture controls

## 📋 Requirements

- Flutter SDK: ^3.9.0
- Dart SDK: ^3.9.0
- Android: API 21+ (Android 5.0+)
- iOS: 12.0+


```yaml
dependencies:
  dio: ^5.9.0                              # HTTP client with interceptors
  provider: ^6.1.5+1                       # State management
  file_picker: ^10.3.7                     # File selection
  flutter_local_notifications: ^19.5.0     # System notifications
  path_provider: ^2.1.5                    # File system paths
  permission_handler: ^12.0.1              # Runtime permissions
  percent_indicator: ^4.2.5                # Progress indicators
  uuid: ^4.5.2                             # Unique IDs
  connectivity_plus: ^6.1.2                # Network monitoring
  shared_preferences: ^2.3.5               # Local storage
  workmanager: ^0.5.2                      # Background tasks
  open_file: ^3.5.10                       # Open downloaded files
```

## 🏗️ Architecture

### Project Structure
```
lib/
├── main.dart
└── features/
    └── file_transfer/
        ├── data/
        │   └── services/
        │       ├── api_service.dart              # Authentication & API calls
        │       ├── file_transfer_service.dart    # Upload/download logic
        │       ├── connectivity_service.dart     # Network monitoring
        │       ├── storage_service.dart          # State persistence
        │       └── permission_service.dart       # Runtime permissions
        ├── domain/
        │   └── transfer_state.dart               # Transfer models & enums
        ├── providers/
        │   └── transfer_provider.dart            # State management
        └── presentation/
            ├── screens/
            │   ├── upload_screen.dart
            │   └── download_screen.dart
            └── widgets/
                ├── transfer_dashboard.dart
                └── transfer_list_item.dart
```

### Design Patterns
- **Clean Architecture**: Separation of concerns (data, domain, presentation)
- **Provider Pattern**: Reactive state management
- **Service Layer**: Encapsulated business logic
- **Repository Pattern**: Data access abstraction

## 🔧 Configuration

### API Endpoints

The app uses the following endpoints:

#### Authentication
```
POST: http://54.241.200.172:8801/auth-ws/oauth2/token
Authorization: Basic Y2xpZW50OnNlY3JldA==
Body:
  - grant_type: password
  - scope: profile
  - username: abir
  - password: ati123
```

#### File Upload
```
PATCH: http://54.241.200.172:8800/setup-ws/api/v1/app/update-app/2
Authorization: Bearer <access_token>
Body (multipart/form-data):
  - jsonPatch: [{"op":"replace","path":"/updateBy","value":123}]
  - file: <selected_file>
```

#### File List (Preview)
```
GET: http://54.241.200.172:8800/setup-ws/api/v1/app/get-permitted-apps?companyId=2
Authorization: Bearer <access_token>
```

### Android Permissions

Required permissions are automatically added to `AndroidManifest.xml`:
- `INTERNET` - Network requests
- `ACCESS_NETWORK_STATE` - Connectivity monitoring
- `POST_NOTIFICATIONS` - Android 13+ notifications
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` - File access (Android 12-)
- `READ_MEDIA_*` - Granular media access (Android 13+)
- `FOREGROUND_SERVICE` - Background operations
- `WAKE_LOCK` - Keep device awake during transfers

## 📱 Usage

### Upload a File

1. Navigate to **Upload Module**
2. Tap **Select File**
3. Choose a file (recommended >50MB for testing)
4. Review file details
5. Tap **Start Upload**
6. Monitor progress in the dashboard
7. Use pause/resume as needed

### Download a File

1. Navigate to **Download Module**
2. Enter a file URL (or use the default test URL)
3. Tap **Start Download**
4. Monitor progress in the dashboard
5. Open downloaded file from the list

### Transfer Dashboard

The dashboard shows all active and recent transfers:
- **Filter**: By status (All, In Progress, Paused, Completed, Failed)
- **Pause/Resume**: Control individual transfers
- **Retry**: Retry failed transfers
- **Clear**: Remove completed transfers
- **Swipe to Delete**: Remove individual items

## 🔍 Key Features Explained

### Background Operation

**Current Implementation:**
- Transfers continue when app is minimized
- System notifications show progress
- Tapping notification returns to app

**Platform Limitations:**
- Android may kill the app after extended background time
- iOS has strict background execution limits
- WorkManager integration can provide true background execution (optional)

### Pause & Resume

**Important Note:**
- Resume functionality **restarts from 0%** due to Dio limitations
- True resumable uploads require chunked upload implementation
- Server must support partial content (Range headers)

**Current Behavior:**
- Pause: Cancels current request, saves state
- Resume: Starts new request from beginning
- Progress is preserved in UI for reference

### Network Resilience

**Auto-Retry Logic:**
- Exponential backoff (1s, 2s, 4s...)
- Max 3 retries for downloads, 2 for uploads
- Skips retry on client errors (4xx except 408, 429)

**Connectivity Monitoring:**
- Real-time network status display
- Auto-resume paused transfers when network returns
- Different handling for WiFi vs Mobile data

### State Persistence

**What's Saved:**
- Active transfers (in-progress, paused, failed)
- Transfer history (last 50 completed)
- Progress, status, error messages
- Retry counts

**What's NOT Saved:**
- Completed transfers (moved to history)
- Canceled transfers
- Actual file data (only metadata)

## 🧪 Testing

### Manual Testing Checklist

#### Upload Testing
- [ ] Select file <50MB
- [ ] Select file >50MB
- [ ] Start upload and verify progress
- [ ] Minimize app, check notification
- [ ] Tap notification to return
- [ ] Pause upload
- [ ] Resume upload
- [ ] Enable airplane mode during upload
- [ ] Disable airplane mode, verify auto-resume
- [ ] Force close app, reopen, check state

#### Download Testing
- [ ] Enter valid URL
- [ ] Enter invalid URL (verify error)
- [ ] Start download and verify progress
- [ ] Check notification updates
- [ ] Pause download
- [ ] Resume download
- [ ] Test network interruption
- [ ] Open downloaded file
- [ ] Verify file saved to correct location

#### Permission Testing
- [ ] First launch - verify permission requests
- [ ] Deny storage permission - verify error
- [ ] Deny notification permission - verify warning
- [ ] Grant permissions from settings

#### Error Scenarios
- [ ] No internet connection
- [ ] Invalid file (empty, too large)
- [ ] Server error (401, 500)
- [ ] Insufficient storage
- [ ] File not found (download)

### Test Files

**Upload Testing:**
- Small: <10MB (quick test)
- Medium: 50-100MB (recommended)
- Large: >200MB (stress test)

**Download Testing:**
- Default test URL: `http://speedtest.tele2.net/100MB.zip`
- Alternative: `http://ipv4.download.thinkbroadband.com/100MB.zip`

## ⚠️ Known Limitations

### 1. Resume from 0%
**Issue**: Resume restarts upload/download from beginning
**Reason**: Dio doesn't support resumable uploads natively
**Workaround**: Implement chunked uploads with server support
**Impact**: Medium - acceptable for most use cases

### 2. Background Execution
**Issue**: App may be killed by system in background
**Reason**: Android/iOS background execution limits
**Workaround**: Implement WorkManager for true background
**Impact**: Low - notifications keep user informed

### 3. Token Expiry
**Issue**: Long transfers may fail if token expires
**Reason**: Access token has limited lifetime
**Workaround**: Token refresh logic implemented
**Impact**: Low - auto-retry handles most cases

### 4. Storage Location
**Issue**: Downloads save to app documents directory
**Reason**: Scoped storage requirements (Android 10+)
**Workaround**: Use SAF (Storage Access Framework) for user-selected location
**Impact**: Low - files are accessible via file manager

## 🚧 Future Enhancements

### Planned Features
- [ ] Chunked upload for true resume support
- [ ] WorkManager integration for guaranteed background execution
- [ ] Multiple file selection and batch operations
- [ ] Upload/download speed limiting
- [ ] WiFi-only mode
- [ ] Scheduled transfers
- [ ] Cloud storage integration (S3, Firebase)
- [ ] Transfer analytics and reporting

### Performance Optimizations
- [ ] Reduce state persistence frequency
- [ ] Implement transfer queue with concurrency limits
- [ ] Add compression for uploads
- [ ] Optimize notification updates

## 🐛 Troubleshooting

### Upload fails immediately
- Check internet connection
- Verify API credentials
- Check file permissions
- Review server logs

### Download doesn't start
- Verify URL is valid and accessible
- Check storage permissions
- Ensure sufficient storage space
- Test URL in browser

### Notifications not showing
- Grant notification permission
- Check Android notification settings
- Verify channel is not blocked
- Test on different Android versions

### App crashes on file selection
- Grant storage permission
- Check file picker configuration
- Verify file exists and is accessible
- Check Android version compatibility

## 📄 License

This project is part of the Flutter POS SAAS application.

## 👥 Contributors

- Development Team
- QA Team
- Product Management

## 📞 Support

For issues and questions:
- Create an issue in the repository
- Contact the development team
- Check documentation

---

**Built with ❤️ using Flutter**
