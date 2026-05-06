# Admin Console

A Flutter Web administration console for school management operations. Built for authorized **Staff Administrators** to manage the complete school lifecycle — enrollment, academics, fees, examinations, documents, communication, and auditing.

> This console is for **Staff Admin role only**. Students, parents, teachers, principals, and trustees use a separate mobile application.

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Feature Modules](#feature-modules)
- [Prerequisites](#prerequisites)
- [Setup & Running](#setup--running)
- [Environment Configuration](#environment-configuration)
- [Testing](#testing)
- [Key Design Decisions](#key-design-decisions)
- [Known Limitations & TODOs](#known-limitations--todos)

---

## Overview

PBHS Admin Console is a single-page web application (Flutter Web) that communicates with a REST API backend. Access control is enforced at two levels:

1. **Router redirect** — unauthenticated users are always redirected to `/login`
2. **Role check** — only the `STAFF_ADMIN` role can access the console after login; all other roles are rejected at the auth layer

The backend is a separate service not included in this repository. All API calls target the `ADMIN_API_BASE_URL` environment variable (see [Environment Configuration](#environment-configuration)).

---

## Tech Stack

| Concern              | Library / Tool               |
|----------------------|------------------------------|
| UI Framework         | Flutter (Web)                |
| State Management     | `flutter_riverpod`           |
| Navigation           | `go_router`                  |
| HTTP Client          | `dio`                        |
| Secure Storage       | `flutter_secure_storage`     |
| Platform-Specific    | Conditional imports (web vs stub) |

---

## Architecture

```
┌──────────────────────────────────┐
│         Presentation Layer       │  Screens + Widgets (per feature module)
└────────────────┬─────────────────┘
                 │
┌────────────────▼─────────────────┐
│        Application Layer         │  Riverpod Providers (state management + orchestration)
└────────────────┬─────────────────┘
                 │
┌────────────────▼─────────────────┐
│           Data Layer             │  Repositories (API wrappers) + Models
└────────────────┬─────────────────┘
                 │
┌────────────────▼─────────────────┐
│       Core / Infrastructure      │  DioClient, Interceptors, Auth, Theme,
│                                  │  Router, SecureStorage, CrashReporter
└──────────────────────────────────┘
```

> Note: This follows a pragmatic layered architecture where Riverpod providers act as the application layer orchestrating repositories, instead of a strict domain/use-case separation.

### Interceptor Chain (per request)

```
Request → [school_id injection] → ErrorInterceptor → RateLimitRetryInterceptor → AuthInterceptor → API
```

- **`ErrorInterceptor`** — normalises connection errors and HTTP 401/403 messages for the UI
- **`RateLimitRetryInterceptor`** — retries HTTP 429 responses with exponential backoff, respecting `Retry-After` header
- **`AuthInterceptor`** — attaches `Bearer` token; on 401, performs a single in-flight refresh and queues concurrent 401 requests to retry after refresh completes; on refresh failure, fires `AuthLogoutBus` to clear session

### Forced Logout Without Coupling

`AuthLogoutBus` is a `StreamController.broadcast()`. Network interceptors call `logoutBus.notifyLogout()` on unrecoverable auth failures. `AuthController` subscribes and clears state. This avoids passing `AuthController` directly into `DioClient`.

---

## Folder Structure

```
lib/
├── core/
│   ├── auth/                        # AuthLogoutBus (broadcast stream for forced logout)
│   ├── cache/                       # TimedMemoryCache (provider-scoped in-process TTL cache, ~25s)
│   ├── constants/
│   │   ├── api_constants.dart       # All API endpoint paths
│   │   ├── brand_constants.dart     # Logo asset, school display name
│   │   └── route_constants.dart     # Named route paths
│   ├── logging/
│   │   └── crash_reporter.dart      # Pluggable error logger (swap Sentry/Crashlytics here)
│   ├── network/
│   │   ├── dio_client.dart          # DioClient: base URL, school_id injection, UUID validation
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart
│   │       ├── error_interceptor.dart
│   │       └── rate_limit_retry_interceptor.dart
│   ├── platform/
│   │   ├── browser_actions.dart     # Conditional import entry point
│   │   ├── browser_actions_web.dart # Web implementation (dart:html)
│   │   └── browser_actions_stub.dart# Non-web no-op stub
│   ├── rbac/
│   │   └── admin_route_access.dart  # routeAccessAllowedForUser
│   ├── router/
│   │   └── app_router.dart          # GoRouter config + redirect guards
│   ├── storage/
│   │   └── secure_storage.dart      # Access token, refresh token, school_id
│   └── theme/
│       ├── admin_colors.dart        # Design token palette
│       └── admin_app_theme.dart     # ThemeData builder (Material 3)
│
├── data/
│   ├── models/
│   │   ├── academics/               # AcademicYearItem, StandardItem, SectionItem, SubjectItem
│   │   ├── audit/                   # AuditLog
│   │   ├── auth/                    # AdminUser, TokenResponse
│   │   ├── communication/           # AdminAnnouncementItem
│   │   ├── dashboard/               # DashboardOverview
│   │   ├── documents/               # AdminDocument, AdminDocRequirement, AdminRequirementStatus
│   │   ├── fees/                    # FeeStructureItem
│   │   ├── lifecycle/               # LifecycleStudentSummary, LifecycleHistoryEntry
│   │   ├── registration/            # RegistrationRequest, ApprovalAction
│   │   └── role_profiles/           # RoleProfileItem, IdentifierConfigItem
│   │
│   └── repositories/
│       ├── academic_repository.dart
│       ├── admin_document_repository.dart
│       ├── announcement_repository.dart
│       ├── approval_repository.dart
│       ├── audit_repository.dart
│       ├── auth_repository.dart
│       ├── dashboard_repository.dart
│       ├── enrollment_repository.dart
│       ├── fee_repository.dart
│       ├── lifecycle_admin_repository.dart
│       ├── masters_repository.dart          # Shared: years / standards / sections
│       ├── principal_reports_repository.dart
│       ├── results_repository.dart
│       ├── role_profile_repository.dart
│       ├── settings_repository.dart
│       └── teacher_assignments_repository.dart
│
├── domains/
│   └── providers/                   # Riverpod providers (one file per feature area)
│       ├── auth_provider.dart       # AuthController, dioClientProvider, secureStorageProvider
│       ├── repository_providers.dart# Central repository wiring
│       ├── active_year_provider.dart
│       ├── academic_phase3_provider.dart
│       ├── approval_provider.dart
│       ├── audit_provider.dart
│       ├── communication_providers.dart
│       ├── dashboard_overview_provider.dart
│       ├── enrollment_provider.dart
│       ├── enrollment_screen_providers.dart
│       ├── fee_repository_provider.dart
│       ├── lifecycle_management_providers.dart
│       ├── role_profile_list_provider.dart
│       ├── results_repository_provider.dart
│       ├── school_settings_provider.dart
│       ├── student_documents_overview_provider.dart
│       └── teacher_assignments_repository_provider.dart
│
└── presentation/
    ├── common/
    │   ├── layout/
    │   │   ├── admin_scaffold.dart  # Shell: top bar + sidebar + content area
    │   │   ├── sidebar.dart         # Navigation rail with active-route detection
    │   │   └── top_bar.dart         # App bar with logout action
    │   └── widgets/
    │       ├── admin_layout/
    │       │   ├── admin_empty_state.dart
    │       │   ├── admin_filter_card.dart
    │       │   ├── admin_loading_placeholder.dart  # Skeleton shimmer
    │       │   ├── admin_page_header.dart
    │       │   ├── admin_spacing.dart              # 8/12/16/24 spacing scale
    │       │   ├── admin_surface_card.dart
    │       │   └── admin_table_helpers.dart        # Zebra striping, heading colour
    │       ├── data_table_widget.dart              # Virtualised table with pagination
    │       └── school_brand_logo.dart
    │
    ├── academics/          # Academic years overview + class/section/subject setup
    ├── approvals/          # Registration queue: list, detail, bulk decisions
    ├── audit/              # Audit log with action/entity filters and before/after diff
    ├── auth/               # Login screen, access-denied screen
    ├── communication/      # Announcements: create, edit, delete, filter
    ├── dashboard/          # Live overview: KPIs, shortcuts, recent audit feed
    ├── documents/          # Document management: requirements, upload, verify
    ├── enrollment/         # Onboarding queue, lifecycle management, promotion workflow
    ├── fees/               # Fee structures, student billing, payment collection, analytics
    ├── reports/            # Principal reports: KPIs, fee collection, result drill-down
    ├── results/            # Examination: create exams, upload results, exam schedules
    ├── role_profiles/      # Browse profiles by role with class/section filters
    ├── settings/           # System settings key-value editor
    └── teacher_assignments/# Teacher-class-subject assignment, leave management
```

---

## Feature Modules

| Module                | Route                     | Description |
|-----------------------|---------------------------|-------------|
| Dashboard             | `/dashboard`              | Live school snapshot: pending approvals, exams configured, classes count, recent audit events |
| Approvals             | `/approvals`              | Registration queue with search, role/status filters, bulk approve/reject/hold |
| Approval Detail       | `/approvals/:userId`      | Full registration detail with validation issues, duplicate matches, decision panel |
| Audit Log             | `/audit`                  | System-wide action trail; filter by action, entity type, date range; expandable before/after state diff |
| Academic Years        | `/academics`              | Create/activate years; preview classes, sections, subjects per year |
| Class Setup           | `/academics/structure`    | Manage standards, sections, subjects per class per year with teacher assignment view |
| Teacher Assignments   | `/teacher-assignments`    | Assign teachers to subject+class+section per year; view by teacher or by class; leave balance management |
| Enrollment            | `/enrollment`             | Onboarding queue for approved users; create student/parent profiles; map students to class/section |
| Student Lifecycle     | `/enrollment/lifecycle`   | Transfer, withdraw, mark year complete, re-enroll; full academic history per student |
| Promotion Workflow    | `/enrollment/promotion`   | Bulk year-end promotion: preview eligible students, override decisions (PROMOTE/REPEAT/GRADUATE/SKIP), execute |
| Role Profiles         | `/role-profiles`          | Browse students, teachers, parents, principals, trustees; link parent-child relationships |
| Fees                  | `/fees`                   | Fee structures, class-wise student billing, payment collection with cycle-aware allocation, analytics, defaulters |
| Examination           | `/examination`            | Create exams (all classes), upload results per student, attach report PDFs, manage exam schedules |
| Reports               | `/reports`                | Principal KPIs: student strength, fee collection rate, result averages; CSV export |
| Communication         | `/communication`          | School-wide announcements targeted by role and/or class; create, edit, deactivate |
| Documents             | `/documents`              | Set document requirements; upload, approve, reject per-student documents; per-student checklist view |
| Document Student View | `/documents/student/:id`  | Per-student checklist with inline verify/reject and file attachment |
| Settings              | `/settings`               | School ID display; system settings key-value editor |

---

## Prerequisites

- Flutter SDK ≥ 3.x  (`flutter --version`)
- Chrome browser (primary development target)
- The backend REST API running and reachable

---

## Setup & Running

### 1. Clone & install

```bash
git clone <repo-url>
cd admin_console
flutter pub get
```

### 2. Run in development (API on localhost)

```bash
# Chrome (standard)
flutter run -d chrome \
  --dart-define=ADMIN_API_BASE_URL=http://127.0.0.1:8000/api/v1

# If testing against an Android emulator backend
flutter run -d chrome \
  --dart-define=ADMIN_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

In debug mode, if `ADMIN_API_BASE_URL` is not provided the app defaults to
`http://127.0.0.1:8000/api/v1` (or `http://<browser-host>:8000/api/v1` when running as a web server).

### 3. Build for production

```bash
flutter build web \
  --dart-define=ADMIN_API_BASE_URL=https://api.yourschool.com/api/v1
```

> **Important:** In release/profile builds, `ADMIN_API_BASE_URL` is **mandatory** and must use `https://`. The app throws a descriptive exception at startup if either condition is violated.

### 4. Serve the production build

```bash
# Simple local preview
cd build/web
python3 -m http.server 8080

# Or deploy the build/web/ directory to any static host (Firebase Hosting, Nginx, S3+CloudFront, etc.)
```

---

## Environment Configuration

| Variable              | Required in Release | Description |
|-----------------------|---------------------|-------------|
| `ADMIN_API_BASE_URL`  | **Yes**             | Base URL of the backend REST API. No trailing slash. Must be `https://` in release builds. In debug, defaults to `http://127.0.0.1:8000/api/v1`. |

Pass via `--dart-define=KEY=VALUE` at `flutter run` or `flutter build` time. No `.env` file is used — values are compiled into the binary.

---

## Testing

Run tests:

```bash
flutter test
```

Minimum regression coverage currently includes:

1. `DioClient.assertValidSchoolId` UUID validation contract
2. `TokenResponse.fromJson` parsing contract
3. `ADMIN_API_BASE_URL` release safety via CI build command with explicit `--dart-define` and `https://` URL

---

## Key Design Decisions

### 1. Token Refresh Strategy

`AuthInterceptor` intercepts 401 responses. It creates a fresh `Dio` instance
(bypassing the main interceptor chain to avoid loops) to POST to `/auth/refresh`.
On success it saves the new access token and retries the original request.
Concurrent 401 responses wait on the same in-flight refresh via a shared
`Completer<String>` and then retry with the refreshed token.
On any refresh failure it clears stored tokens and calls
`AuthLogoutBus.notifyLogout()`.

### 2. Forced Logout Decoupling

`AuthLogoutBus` is a `StreamController.broadcast()` provided via Riverpod.
Networking code (interceptors) can trigger logout by calling `notifyLogout()`
without any direct reference to `AuthController`. `AuthController` subscribes
in its constructor and sets state to `AsyncData(null)`, which causes `GoRouter`
to redirect to `/login`.

### 3. School ID Injection

`DioClient` automatically appends `?school_id=<uuid>` to all non-auth API calls
using the school ID persisted after login. It validates UUID format before sending
and skips injection if the value is empty or malformed.

> **Security note (in source):** The backend must derive the actual tenant from
> the JWT and treat the client-sent `school_id` as advisory only. The client
> value is a developer convenience, not an authorization mechanism.

### 4. In-Process TTL Cache

`TimedMemoryCache` stores list responses with a configurable TTL (typically 25s)
keyed by role + filters. It is now instance-based and provided via Riverpod
(`timedCacheProvider`) instead of static global state, so cache lifecycle is
scoped and testable. Prefix-based invalidation is used after mutations so stale
data is never displayed after a write.

### 5. Fee Module Extraction

Fee payment suggestion logic has been moved out of the fee screen into:
`lib/presentation/fees/use_cases/fee_payment_calculator.dart`

This keeps installment-targeting logic (`suggestedAmountForCycle`,
`nextInstallmentsForCycle`) isolated and testable as use-case code rather than
UI state code.

### 6. Route Access Control

Route access is intentionally coarse at the Flutter layer: any authenticated
`STAFF_ADMIN` can reach any route. The router redirect guard is the enforcement
point for unauthenticated access. Fine-grained permission checks (e.g., `canDecide`,
`canReview`) are evaluated per-screen using the `permissions` list on `AdminUser`,
and the backend enforces its own authorization independently.

### 7. Platform-Specific Code

Browser-only APIs (`window.open`, Blob download) are isolated behind a conditional
import pattern:

```dart
// browser_actions.dart (entry point — works on all platforms)
import 'browser_actions_stub.dart'
    if (dart.library.html) 'browser_actions_web.dart' as impl;
```

This prevents `dart:html` from being compiled into non-web builds.

---
