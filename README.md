# Faculty Pedia Mobile App

A comprehensive Flutter mobile application for Faculty Pedia - an educational platform connecting students with top educators.

## Features

### Core Features
- **User Authentication**: JWT-based login/signup for Students and Educators
- **Home Dashboard**: Browse exam categories, courses, and quick actions
- **Educators**: Browse, search, and view educator profiles
- **Courses**: Browse courses, view details, and enroll
- **Test Series**: Access practice tests with timed assessments
- **Live Tests**: Take real-time tests with scoring
- **Webinars**: Join live and upcoming webinars
- **Profile Management**: View and edit user profile

### Additional Features
- **Dark Mode**: Full dark theme support
- **Push Notifications**: Firebase-based notifications

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **HTTP Client**: Dio
- **Local Storage**: SharedPreferences, FlutterSecureStorage
- **Push Notifications**: Firebase Messaging

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── config/              # App configuration
│   ├── router/              # Navigation setup
│   ├── services/            # API, storage, notification services
│   ├── theme/               # App theming
│   └── utils/               # Utility functions
├── features/
│   ├── auth/                # Login, Signup, Forgot Password
│   ├── splash/              # Splash screen
│   ├── home/                # Home dashboard
│   ├── educators/           # Educators list & profiles
│   ├── courses/             # Courses list & details
│   ├── exams/               # Exam categories
│   ├── test_series/         # Test series
│   ├── live_test/           # Live test taking
│   ├── webinars/            # Webinars
│   ├── profile/             # User profile
│   └── settings/            # App settings
└── shared/
    ├── models/              # Data models
    └── widgets/             # Reusable widgets
```

## Screens

1. **Splash Screen** - App initialization with branding
2. **Login Screen** - Email/password authentication
3. **Signup Screen** - Student/Educator registration
4. **Forgot Password** - Password reset flow
5. **Home Dashboard** - Main landing with categories
6. **Educators List** - Browse all educators
7. **Educator Profile** - Detailed educator view
8. **Courses List** - Browse all courses
9. **Course Details** - Course information and enrollment
10. **Exams Screen** - IIT-JEE, NEET, CBSE categories
11. **Exam Details** - Courses and tests by exam type
12. **Test Series** - Available test series
13. **Test Series Details** - Tests within a series
14. **Live Test** - Test taking interface
15. **Test Results** - Score and performance analysis
16. **Webinars List** - Upcoming and past webinars
17. **Webinar Details** - Webinar information
18. **Profile** - User profile and stats
19. **Edit Profile** - Update user information
20. **Settings** - App preferences and logout

