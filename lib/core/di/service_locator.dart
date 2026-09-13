import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../services/session_storage_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_permission_service.dart';
import '../services/download_service.dart';
import '../services/realtime_sync_service.dart';
import '../services/student_notes_service.dart';
import '../services/course_interaction_service.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/certificate_remote_datasource.dart';
import '../../data/datasources/checkout_remote_datasource.dart';
import '../../data/datasources/course_remote_datasource.dart';
import '../../data/datasources/payment_remote_datasource.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/certificate_repository_impl.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../data/repositories/payment_repository_impl.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/payment_repository.dart';

import '../../domain/usecases/auth_usecase.dart';
import '../../domain/usecases/certificate_usecase.dart';
import '../../domain/usecases/checkout_usecase.dart';
import '../../domain/usecases/get_courses_usecase.dart';
import '../../domain/usecases/process_payment_usecase.dart';

import '../../presentation/viewmodels/auth_viewmodel.dart';
import '../../presentation/viewmodels/certificate_viewmodel.dart';
import '../../presentation/viewmodels/course_viewmodel.dart';
import '../../presentation/viewmodels/learning_viewmodel.dart';
import '../../presentation/viewmodels/notification_viewmodel.dart';
import '../../presentation/viewmodels/payment_viewmodel.dart';
import '../../presentation/viewmodels/theme_viewmodel.dart';
import '../../presentation/viewmodels/download_viewmodel.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core Services
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: false,
      ),
    ),
  );
  sl.registerLazySingleton<SessionStorageService>(
    () => SessionStorageService(secureStorage: sl()),
  );
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sessionStorage: sl(), storage: sl()));
  sl.registerLazySingleton<BiometricService>(() => BiometricService(sessionStorage: sl(), storage: sl()));
  sl.registerLazySingleton<NotificationPermissionService>(() => NotificationPermissionService());

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<CourseRemoteDataSource>(
    () => CourseRemoteDataSourceImpl(apiClient: sl(), storage: sl()),
  );
  sl.registerLazySingleton<PaymentRemoteDataSource>(
    () => PaymentRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<CheckoutRemoteDataSource>(
    () => CheckoutRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<CertificateRemoteDataSource>(
    () => CertificateRemoteDataSourceImpl(apiClient: sl(), storage: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<CourseRepository>(
    () => CourseRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(
      remoteDataSource: sl(),
      checkoutRemoteDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<CertificateRepository>(
    () => CertificateRepositoryImpl(remoteDataSource: sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => AuthUseCase(sl()));
  sl.registerLazySingleton(() => GetCoursesUseCase(sl()));
  sl.registerLazySingleton(() => ProcessPaymentUseCase(sl()));
  sl.registerLazySingleton(() => CheckoutUseCase(sl()));
  sl.registerLazySingleton(() => CertificateUseCase(sl()));

  // ViewModels
  sl.registerLazySingleton(
    () => AuthViewModel(
      authUseCase: sl(),
      biometricService: sl(),
      permissionService: sl(),
      storage: sl(),
      sessionStorage: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => CourseViewModel(
      getCoursesUseCase: sl(),
      storage: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => LearningViewModel(
      getCoursesUseCase: sl(),
      storage: sl(),
    ),
  );
  sl.registerFactory(
    () => PaymentViewModel(
      processPaymentUseCase: sl(),
      checkoutUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => CertificateViewModel(certificateUseCase: sl()),
  );
  sl.registerLazySingleton(
    () => NotificationViewModel(),
  );
  sl.registerLazySingleton(
    () => ThemeViewModel(),
  );

  sl.registerLazySingleton<DownloadService>(() => DownloadService(storage: sl()));
  sl.registerLazySingleton(() => DownloadViewModel(service: sl()));

  // Student Notes & Course Interaction Services
  sl.registerLazySingleton<StudentNotesService>(() => StudentNotesService(storage: sl()));
  sl.registerLazySingleton<CourseInteractionService>(() => CourseInteractionService(storage: sl()));

  // Real-time Course Synchronization Service
  sl.registerLazySingleton(
    () => RealtimeSyncService(
      courseViewModel: sl(),
      notificationViewModel: sl(),
    ),
  );
}
