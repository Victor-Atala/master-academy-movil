# Master Academy - Flutter App

Aplicación móvil construida en Flutter aplicando **Clean Architecture**, patrón **MVVM**, **ciclos de vida (`WidgetsBindingObserver`)** y simulación de **pasarela de pagos segura**.

## 🏗️ Arquitectura de Carpetas

```text
lib/
├── core/
│   ├── constants/
│   │   └── app_colors.dart
│   └── errors/
│       └── failures.dart
├── data/
│   ├── datasources/
│   │   ├── course_remote_datasource.dart
│   │   └── payment_remote_datasource.dart
│   ├── models/
│   │   └── course_model.dart
│   └── repositories/
│       ├── course_repository_impl.dart
│       └── payment_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── course.dart
│   │   └── payment_result.dart
│   ├── repositories/
│   │   ├── course_repository.dart
│   │   └── payment_repository.dart
│   └── usecases/
│       ├── get_courses_usecase.dart
│       └── process_payment_usecase.dart
├── presentation/
│   ├── viewmodels/
│   │   ├── auth_viewmodel.dart
│   │   ├── course_viewmodel.dart
│   │   └── payment_viewmodel.dart
│   ├── views/
│   │   ├── auth/
│   │   │   ├── auth_screen.dart
│   │   │   └── registry_screen.dart
│   │   ├── categories/
│   │   │   └── categories_screen.dart
│   │   ├── course_detail/
│   │   │   └── course_detail_screen.dart
│   │   └── home/
│   │       ├── home_screen.dart
│   │       └── main_navigation_shell.dart
│   └── widgets/
│       ├── bottom_nav.dart
│       └── course_card.dart
└── main.dart
```

## 🚀 Características
- **Clean Architecture & MVVM**: Separación estricta de capas (Data, Domain, Presentation).
- **Manejo de Estado**: Reactivo con `ChangeNotifier` y `Provider`.
- **Ciclo de Vida**: Manejo de `WidgetsBindingObserver` para sincronización al reanudar la app.
- **Flujo de Pago**: Modal desacoplado con estados `idle`, `processing`, `success`, `failed`.
- **Autenticación**: Flujo dinámico entre login, registro y navegación principal.
