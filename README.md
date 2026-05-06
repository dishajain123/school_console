Admin Console

A Flutter web-first school administration console for STAFF_ADMIN operations: approvals, academics, enrollment lifecycle, teacher assignments, fees, exams/results, reports, communication, document verification, audit logs, and settings.

1. Project Overview

This app is the authenticated admin frontend for school-office workflows.

Primary role: STAFF_ADMIN only (enforced in auth/session flow)
Purpose: centralize school master-data and operational workflows in one console
Current routed scope: authentication, dashboard, approvals, audit, academics, enrollment, teacher assignments, role profiles, fees, examination/results, reports, communication, documents, settings
2. Tech Stack
Flutter + Dart
SDK constraint: ^3.11.4 (from pubspec.yaml)
State management: flutter_riverpod (^2.6.1)
Routing: go_router (^13.2.5)
Networking: dio (^5.9.0)
File handling: file_picker (^8.0.3)
Secure storage: flutter_secure_storage (^9.2.4)
Theming: custom Material 3 setup in lib/core/theme/
3. Project Setup

This is a web-first Flutter admin console.
Primary development target is Chrome (Flutter Web). Mobile is optional for testing only.

Install dependencies
flutter pub get
Run (Web - Primary Development Mode)
flutter run -d chrome --dart-define=ADMIN_API_BASE_URL=http://127.0.0.1:8000/api/v1
Run (Android - Optional Testing Only)
flutter run -d android --dart-define=ADMIN_API_BASE_URL=http://10.0.2.2:8000/api/v1
Analyze
flutter analyze
Build APK
flutter build apk
Build Web (Production)
flutter build web --dart-define=ADMIN_API_BASE_URL=https://your-api-host/api/v1
API Base URL (ADMIN_API_BASE_URL)

Runtime base URL is injected using:

--dart-define=ADMIN_API_BASE_URL=...

Examples:

flutter run -d chrome --dart-define=ADMIN_API_BASE_URL=http://127.0.0.1:8000/api/v1
flutter run -d android --dart-define=ADMIN_API_BASE_URL=http://10.0.2.2:8000/api/v1
flutter build web --dart-define=ADMIN_API_BASE_URL=https://your-api-host/api/v1
Code Enforced Behavior
release/profile: ADMIN_API_BASE_URL is required
release: URL must be https://
4. Current lib/ Structure
lib
├── core
│   ├── auth
│   ├── cache
│   ├── constants
│   ├── logging
│   ├── network
│   │   └── interceptors
│   ├── platform
│   ├── rbac
│   ├── router
│   ├── storage
│   └── theme
├── data
│   ├── models
│   │   ├── academics
│   │   ├── audit
│   │   ├── auth
│   │   ├── communication
│   │   ├── dashboard
│   │   ├── documents
│   │   ├── fees
│   │   ├── lifecycle
│   │   ├── registration
│   │   └── role_profiles
│   └── repositories
├── domains
│   └── providers
├── presentation
│   ├── academics
│   │   └── screens
│   ├── approvals
│   ├── audit
│   │   └── screens
│   ├── auth
│   ├── common
│   ├── communication
│   ├── dashboard
│   ├── documents
│   │   └── screens
│   ├── enrollment
│   ├── fees
│   ├── reports
│   ├── results
│   ├── role_profiles
│   ├── settings
│   ├── teacher_assignments
│   ├── academic_history
│   └── teacher_schedule
└── main.dart

Notes:

academic_history and teacher_schedule are present but not yet routed features.
5. Architecture Overview

UI Screen → Riverpod Provider → Repository → DioClient → Backend API

6. Authentication and Session Flow

Core files:

domains/providers/auth_provider.dart
data/repositories/auth_repository.dart
core/network/interceptors/auth_interceptor.dart
core/auth/auth_logout_bus.dart

Flow:

Login via POST /auth/login
Token stored in flutter_secure_storage
User loaded via GET /auth/me
Auto session restore on app bootstrap
401 triggers refresh (POST /auth/refresh) then forced logout if failed
7. API Layer
Base URL: ApiConstants.baseUrl
Dio interceptors:
AuthInterceptor
ErrorInterceptor
RateLimitRetryInterceptor (429 handling)

Tenant/security is enforced by backend JWT validation.

8. Routed Features (GoRouter)

All routes are protected (STAFF_ADMIN only):

/login
/access-denied
/dashboard
/approvals
/approvals/:userId
/audit
/academics
/academics/structure
/enrollment
/enrollment/lifecycle
/enrollment/promotion
/teacher-assignments
/role-profiles
/fees
/examination
/reports
/communication
/documents
/documents/student/:studentId
/settings
9. State Management Patterns
Provider → repositories/services
StateNotifierProvider → auth/session/UI state
FutureProvider → async server-driven screens
TimedMemoryCache → temporary in-memory caching
10. Constraints
Backend is mandatory for all core features
RBAC enforced by backend (frontend only UI gating)
Secure token storage via flutter_secure_storage
No offline-first support
No websocket realtime system (polling used in limited modules)
11. Development Conventions
API calls → data/repositories/
Providers → domains/providers/
UI → presentation/<feature>/screens
Shared widgets → presentation/common
Constants → core/constants/api_constants.dart
12. Known Limitations
Polling exists in:
approvals (Timer.periodic ~10s)
enrollment (Timer.periodic ~15s)
TimedMemoryCache is in-memory only
academic_history and teacher_schedule are placeholders
13. What Is Not Included
Multi-role system (currently single STAFF_ADMIN)
Offline support
Persistent caching layer
WebSocket real-time system
Business authorization logic (handled by backend)
14. CI / Build Pipeline

GitHub Actions: .github/workflows/flutter-ci.yml

Pipeline:

flutter pub get
flutter analyze --no-fatal-infos
flutter test -r expanded
flutter build web --dart-define=ADMIN_API_BASE_URL=...

CI mirrors production web build behavior