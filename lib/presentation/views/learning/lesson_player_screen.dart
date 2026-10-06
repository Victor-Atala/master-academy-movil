import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/download_service.dart';
import '../../../domain/entities/course.dart';
import '../../../domain/entities/syllabus.dart';
import '../../viewmodels/course_viewmodel.dart';
import '../../viewmodels/download_viewmodel.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/certificate_viewer_modal.dart';
import '../../widgets/resource_viewer_modal.dart';
import '../../widgets/download_destination_modal.dart';
import '../profile/saved_lessons_screen.dart';
import '../../../core/services/student_notes_service.dart';
import '../notes/student_notebook_screen.dart';
import '../../widgets/course_rating_modal.dart';
import '../../widgets/instructor_inquiry_modal.dart';
import '../../widgets/youtube_style_comments_section.dart';
import '../quiz/quiz_screen.dart';
import '../../../core/services/quiz_service.dart';
import '../../../domain/entities/quiz.dart';

class LessonPlayerScreen extends StatefulWidget {
  final Course course;
  final int? initialLessonId;

  const LessonPlayerScreen({
    super.key,
    required this.course,
    this.initialLessonId,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isLoadingVideo = false;
  bool _isUsingNativeVideo = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  bool _hasCompletedCurrent = false;
  bool _isFullscreen = false;

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // Offline & Playback State
  bool _isOfflineNotDownloaded = false;
  bool _isPlayingOfflineDownloaded = false;
  bool _isWebVideo = false;
  WebViewController? _webViewController;
  bool _hasVideoPlaybackError = false;
  Set<int> _downloadedLessonIds = {};

  // Token anti-race condition para cambios rápidos de video
  int _currentMediaToken = 0;

  // Persistencia del estado de módulos/secciones abiertos o cerrados por el usuario
  final Map<int, bool> _sectionExpandedState = {};

  // Notes state
  final TextEditingController _notesController = TextEditingController();
  bool _isSavingNote = false;
  bool _noteSavedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _loadDownloadedLessonIds();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<LearningViewModel>();
      await vm.loadCourseSyllabus(widget.course.id);
      Lesson? targetLesson;
      if (widget.initialLessonId != null) {
        for (final section in vm.sections) {
          for (final lesson in section.lessons) {
            if (lesson.id == widget.initialLessonId) {
              targetLesson = lesson;
              break;
            }
          }
          if (targetLesson != null) break;
        }

        if (targetLesson == null) {
          try {
            final downloadService = sl<DownloadService>();
            final saved = await downloadService.getSavedLesson(widget.initialLessonId!);
            if (saved != null) {
              targetLesson = Lesson(
                id: saved.lessonId,
                syllabusId: 0,
                title: saved.lessonTitle,
                description: 'Clase descargada para reproducción offline.',
                videoUrl: saved.localFilePath,
                durationSeconds: 0,
                order: 1,
                type: saved.localFilePath.endsWith('.txt') ? 'reading' : 'video',
              );
            }
          } catch (_) {}
        }
      }
      final lessonToPlay = targetLesson ?? vm.activeLesson;
      if (lessonToPlay != null) {
        vm.selectLesson(lessonToPlay);
        // Pequeño diferimiento para permitir que la transición de pantalla termine fluida a 60/120 FPS
        await Future.delayed(const Duration(milliseconds: 160));
        if (mounted) {
          _initializeLessonMedia(lessonToPlay);
        }
      }
    });
  }

  Future<void> _loadDownloadedLessonIds() async {
    try {
      final downloadService = sl<DownloadService>();
      final saved = await downloadService.getSavedLessons();
      if (mounted) {
        setState(() {
          _downloadedLessonIds = saved.map((s) => s.lessonId).toSet();
        });
      }
    } catch (_) {}
  }

  String? _extractYouTubeId(String url) {
    final trimmed = url.trim();
    if (trimmed.length == 11 && !trimmed.contains('/') && !trimmed.contains('?')) {
      return trimmed;
    }
    try {
      final regExp = RegExp(
        r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/|live\/))([\w-]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(trimmed);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  String? _extractGoogleDriveId(String url) {
    try {
      final regExp1 = RegExp(r'(?:drive|docs)\.google\.com\/file\/(?:u\/\d+\/)?d\/([a-zA-Z0-9_-]+)');
      final match1 = regExp1.firstMatch(url);
      if (match1 != null) return match1.group(1);

      final regExp2 = RegExp(r'(?:drive|docs)\.google\.com\/(?:open|uc)\?id=([a-zA-Z0-9_-]+)');
      final match2 = regExp2.firstMatch(url);
      if (match2 != null) return match2.group(1);
    } catch (_) {}
    return null;
  }

  String _buildYouTubeHtml(String ytId) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000000;
      overflow: hidden;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: 0;
    }
  </style>
</head>
<body>
  <iframe
    src="https://www.youtube-nocookie.com/embed/$ytId?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
  }

  String _buildGoogleDriveHtml(String driveId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000000;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: 0;
    }
  </style>
</head>
<body>
  <iframe
    src="https://drive.google.com/file/d/$driveId/preview"
    allow="autoplay; fullscreen"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
  }

  String? _extractVimeoId(String url) {
    try {
      final regExp = RegExp(
        r'(?:vimeo\.com\/(?:video\/|channels\/(?:\w+\/)?|groups\/[^\/]*\/videos\/|album\/(?:\d+\/)?video\/|))(\d+)',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(url.trim());
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  String _buildVimeoHtml(String vimeoId) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000000;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: 0;
    }
  </style>
</head>
<body>
  <iframe
    src="https://player.vimeo.com/video/$vimeoId?autoplay=1&playsinline=1"
    allow="autoplay; fullscreen; picture-in-picture"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
  }

  void _initializeWebVideoPlayer({
    String? directUrl,
    String? embedHtml,
    String? originalUrl,
    String? baseUrl,
    int? token,
  }) {
    if (token != null && token != _currentMediaToken) return;

    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        final old = _videoController!;
        _videoController = null;
        old.dispose();
      } catch (_) {}
    }

    if (_webViewController != null) {
      try {
        _webViewController!.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
      _webViewController = null;
    }

    final isYouTube = (embedHtml != null && (embedHtml.contains('youtube.com') || embedHtml.contains('youtu.be'))) ||
        (directUrl != null && (directUrl.contains('youtube.com') || directUrl.contains('youtu.be')));

    // Agente móvil estándar de Chrome Android para decodificación nativa de video HTML5
    const mobileUserAgent =
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(mobileUserAgent);

    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          return NavigationDecision.navigate;
        },
        onPageFinished: (String url) {
          if (isYouTube) {
            controller.runJavaScript('''
              (function() {
                function hideInside(doc) {
                  if (!doc) return;
                  var selectors = [
                    '.ytp-pause-overlay',
                    '.ytp-expand-pause-overlay',
                    '.ytp-cards-teaser',
                    '.ytp-cards-button',
                    '.ytp-ce-element',
                    '.ytp-show-tiles',
                    '.ytp-more-videos',
                    '.ytp-suggested-action',
                    'button[aria-label*="Más videos"]',
                    'button[aria-label*="More videos"]'
                  ];
                  for (var i = 0; i < selectors.length; i++) {
                    var els = doc.querySelectorAll(selectors[i]);
                    for (var j = 0; j < els.length; j++) {
                      els[j].style.setProperty('display', 'none', 'important');
                      els[j].style.setProperty('opacity', '0', 'important');
                      els[j].style.setProperty('pointer-events', 'none', 'important');
                    }
                  }
                }
                function hideAll() {
                  hideInside(document);
                  var iframes = document.querySelectorAll('iframe');
                  for (var k = 0; k < iframes.length; k++) {
                    try {
                      hideInside(iframes[k].contentDocument);
                    } catch(e) {}
                  }
                }
                hideAll();
                setInterval(hideAll, 1200);
              })();
            ''').catchError((_) {});
          }
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('WebVideo error: \${error.description}');
        },
      ),
    );

    if (embedHtml != null && embedHtml.isNotEmpty) {
      controller.loadHtmlString(
        embedHtml,
        baseUrl: baseUrl ?? (isYouTube ? 'https://www.youtube.com' : 'https://masteracademy.mx'),
      );
    } else if (directUrl != null && directUrl.isNotEmpty) {
      controller.loadRequest(
        Uri.parse(directUrl),
        headers: {
          'Referer': baseUrl ?? (isYouTube ? 'https://www.youtube.com' : 'https://masteracademy.mx'),
          'Origin': baseUrl ?? (isYouTube ? 'https://www.youtube.com' : 'https://masteracademy.mx'),
        },
      );
    }

    if (mounted && (token == null || token == _currentMediaToken)) {
      setState(() {
        _webViewController = controller;
        _isWebVideo = true;
        _isLoadingVideo = false;
        _isUsingNativeVideo = false;
        _isPlayingOfflineDownloaded = false;
        _isOfflineNotDownloaded = false;
        _hasVideoPlaybackError = false;
      });
    }
  }

  Future<void> _initializeLessonMedia(Lesson lesson) async {
    final token = ++_currentMediaToken;
    _hasCompletedCurrent = lesson.isCompleted;
    
    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        final old = _videoController!;
        _videoController = null;
        await old.dispose();
      } catch (_) {}
    }

    if (_webViewController != null) {
      try {
        await _webViewController!.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
      _webViewController = null;
    }

    if (!mounted || token != _currentMediaToken) return;

    setState(() {
      _isLoadingVideo = true;
      _isUsingNativeVideo = false;
      _isWebVideo = false;
      _isPlayingOfflineDownloaded = false;
      _isOfflineNotDownloaded = false;
      _hasVideoPlaybackError = false;
    });

    // Cargar notas personales
    _loadLessonNotes(lesson.id);

    // 0. Si la lección es de tipo lectura escrita (sin video)
    if (lesson.isReading) {
      if (mounted && token == _currentMediaToken) {
        setState(() {
          _isLoadingVideo = false;
          _isUsingNativeVideo = false;
          _isWebVideo = false;
          _isPlayingOfflineDownloaded = false;
          _isOfflineNotDownloaded = false;
          _hasVideoPlaybackError = false;
        });
      }
      return;
    }

    if (!mounted || token != _currentMediaToken) return;
    final courseVm = Provider.of<CourseViewModel>(context, listen: false);

    final rawUrl = lesson.videoUrl?.trim() ?? '';
    final ytId = _extractYouTubeId(rawUrl);
    final driveId = _extractGoogleDriveId(rawUrl);

    // 1. Lección de YouTube -> Reproducir vía YouTube iframe embed dentro de la app
    if (ytId != null && ytId.isNotEmpty) {
      if (courseVm.isOffline) {
        if (mounted && token == _currentMediaToken) {
          setState(() {
            _isLoadingVideo = false;
            _isUsingNativeVideo = false;
            _isWebVideo = false;
            _isPlayingOfflineDownloaded = false;
            _isOfflineNotDownloaded = true;
            _hasVideoPlaybackError = false;
          });
        }
        return;
      }

      final ytDirectUrl = 'https://www.youtube-nocookie.com/embed/$ytId?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1';
      _initializeWebVideoPlayer(
        directUrl: ytDirectUrl,
        embedHtml: _buildYouTubeHtml(ytId),
        baseUrl: 'https://www.youtube-nocookie.com',
        originalUrl: rawUrl,
        token: token,
      );
      return;
    }

    // 2. Lección de Google Drive -> Reproducir vía Google Drive preview dentro de la app
    if (driveId != null && driveId.isNotEmpty) {
      if (courseVm.isOffline) {
        if (mounted && token == _currentMediaToken) {
          setState(() {
            _isLoadingVideo = false;
            _isUsingNativeVideo = false;
            _isWebVideo = false;
            _isPlayingOfflineDownloaded = false;
            _isOfflineNotDownloaded = true;
            _hasVideoPlaybackError = false;
          });
        }
        return;
      }

      final driveDirectUrl = 'https://drive.google.com/file/d/$driveId/preview';
      _initializeWebVideoPlayer(
        directUrl: driveDirectUrl,
        embedHtml: _buildGoogleDriveHtml(driveId),
        baseUrl: 'https://drive.google.com',
        originalUrl: rawUrl,
        token: token,
      );
      return;
    }

    // 2.5. Lección de Vimeo -> Reproducir vía Vimeo player embed
    final vimeoId = _extractVimeoId(rawUrl);
    if (vimeoId != null && vimeoId.isNotEmpty) {
      if (courseVm.isOffline) {
        if (mounted && token == _currentMediaToken) {
          setState(() {
            _isLoadingVideo = false;
            _isUsingNativeVideo = false;
            _isWebVideo = false;
            _isPlayingOfflineDownloaded = false;
            _isOfflineNotDownloaded = true;
            _hasVideoPlaybackError = false;
          });
        }
        return;
      }

      final vimeoDirectUrl = 'https://player.vimeo.com/video/$vimeoId?autoplay=1&playsinline=1';
      _initializeWebVideoPlayer(
        directUrl: vimeoDirectUrl,
        embedHtml: _buildVimeoHtml(vimeoId),
        baseUrl: 'https://player.vimeo.com',
        originalUrl: rawUrl,
        token: token,
      );
      return;
    }

    // 3. Para videos subidos directamente (.mp4, archivos en servidor):
    bool isLocallyDownloaded = false;
    File? downloadedFile;
    try {
      final downloadService = sl<DownloadService>();
      final saved = await downloadService.getSavedLesson(lesson.id);
      if (saved != null) {
        final localFile = File(saved.localFilePath);
        if (localFile.existsSync() && (await localFile.length()) >= 50000) {
          isLocallyDownloaded = true;
          downloadedFile = localFile;
        }
      }
    } catch (_) {}

    if (!mounted || token != _currentMediaToken) return;

    // 4. Si el video directo está descargado en el dispositivo, reproducirlo localmente (100% offline)
    if (isLocallyDownloaded && downloadedFile != null) {
      try {
        final controller = VideoPlayerController.file(downloadedFile);
        await controller.initialize();
        if (!mounted || token != _currentMediaToken) {
          controller.dispose();
          return;
        }
        if (controller.value.isInitialized) {
          final realSecs = controller.value.duration.inSeconds;
          if (realSecs > 0) {
            context.read<LearningViewModel>().updateActiveLessonDuration(realSecs);
          }
          _videoController = controller;
          setState(() {
            _isLoadingVideo = false;
            _isUsingNativeVideo = true;
            _isWebVideo = false;
            _isPlayingOfflineDownloaded = true;
            _isOfflineNotDownloaded = false;
            _hasVideoPlaybackError = false;
          });
          controller.addListener(_videoListener);
          await controller.play();
          _scheduleAutoHideControls();
          return;
        }
      } catch (_) {}
    }

    // 5. Si NO está descargado y la app está en modo offline:
    if (courseVm.isOffline) {
      if (mounted && token == _currentMediaToken) {
        setState(() {
          _isLoadingVideo = false;
          _isUsingNativeVideo = false;
          _isWebVideo = false;
          _isPlayingOfflineDownloaded = false;
          _isOfflineNotDownloaded = true;
          _hasVideoPlaybackError = false;
        });
      }
      return;
    }

    // 6. Streaming directo nativo (.mp4, etc.)
    if (rawUrl.isEmpty) {
      if (mounted && token == _currentMediaToken) {
        setState(() {
          _isLoadingVideo = false;
          _isUsingNativeVideo = false;
          _isWebVideo = false;
          _isPlayingOfflineDownloaded = false;
          _isOfflineNotDownloaded = false;
          _hasVideoPlaybackError = false;
        });
      }
      return;
    }

    final videoUrl = rawUrl;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || token != _currentMediaToken) {
        controller.dispose();
        return;
      }
      if (controller.value.isInitialized) {
        final realSecs = controller.value.duration.inSeconds;
        if (realSecs > 0) {
          context.read<LearningViewModel>().updateActiveLessonDuration(realSecs);
        }
        _videoController = controller;
        setState(() {
          _isLoadingVideo = false;
          _isUsingNativeVideo = true;
          _isWebVideo = false;
          _isPlayingOfflineDownloaded = false;
          _isOfflineNotDownloaded = false;
          _hasVideoPlaybackError = false;
        });
        controller.addListener(_videoListener);
        await controller.play();
        _scheduleAutoHideControls();
        return;
      }
    } catch (_) {
      if (!mounted || token != _currentMediaToken) return;

      // Fallback: Si no pudo decodificar con reproductor nativo pero es URL web válida
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        _initializeWebVideoPlayer(
          directUrl: rawUrl,
          originalUrl: rawUrl,
          token: token,
        );
        return;
      }

      if (mounted && token == _currentMediaToken) {
        setState(() {
          _isLoadingVideo = false;
          _isUsingNativeVideo = false;
          _isWebVideo = false;
          _isPlayingOfflineDownloaded = false;
          _isOfflineNotDownloaded = false;
          _hasVideoPlaybackError = true;
        });
      }
    }
  }

  Timer? _controlsHideTimer;

  void _scheduleAutoHideControls() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isUsingNativeVideo && (_videoController?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _loadLessonNotes(dynamic lessonId) async {
    try {
      final storage = sl<FlutterSecureStorage>();
      final note = await storage.read(key: 'lesson_notes_$lessonId');
      if (mounted) {
        setState(() {
          _notesController.text = note ?? '';
          _noteSavedSuccessfully = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notesController.text = '';
        });
      }
    }
  }

  Future<void> _saveLessonNotes(dynamic lessonId) async {
    setState(() => _isSavingNote = true);
    try {
      final activeLesson = context.read<LearningViewModel>().activeLesson;
      final notesService = sl<StudentNotesService>();
      final parsedId = int.tryParse('$lessonId') ?? 0;
      await notesService.saveNote(
        courseId: widget.course.id,
        courseTitle: widget.course.title,
        lessonId: parsedId,
        lessonTitle: activeLesson?.title ?? 'Clase #$lessonId',
        content: _notesController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isSavingNote = false;
          _noteSavedSuccessfully = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Nota guardada en tu Bloc de Notas!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Ver Bloc',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  StudentNotebookScreen.route(),
                );
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingNote = false);
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;

    final value = _videoController!.value;
    final duration = value.duration;
    final position = value.position;

    // Detect completion automatically when video reaches end
    if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 600)) {
      _onLessonFinished();
    }
  }

  void _onLessonFinished() {
    if (!_hasCompletedCurrent) {
      _hasCompletedCurrent = true;
      final learningVm = context.read<LearningViewModel>();
      final courseVm = context.read<CourseViewModel>();
      
      final active = learningVm.activeLesson;
      if (active != null) {
        learningVm.markLessonAsCompleted(active, courseId: widget.course.id).then((_) {
          if (mounted) {
            // Synchronize course overall progress in course list & padrón
            courseVm.updateCourseProgress(widget.course.id, learningVm.progressPercentage);
            _showLessonCompletedCelebration(active);
          }
        });
      }
    }
  }

  void _showLessonCompletedCelebration(Lesson lesson) {
    final vm = context.read<LearningViewModel>();
    final isAllCompleted = vm.progressPercentage >= 100.0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isAllCompleted ? const Color(0xFFFFB800) : const Color(0xFF10B981),
            width: 1.5,
          ),
        ),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            CircleAvatar(
              backgroundColor: isAllCompleted ? const Color(0xFFFFB800) : const Color(0xFF10B981),
              radius: 16,
              child: Icon(
                isAllCompleted ? Icons.workspace_premium_rounded : Icons.check,
                color: isAllCompleted ? const Color(0xFF0F172A) : Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAllCompleted ? '¡Curso 100% Completado! 🎓' : '¡Clase Finalizada!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    isAllCompleted
                        ? '¡Felicidades! Ya puedes reclamar tu certificado.'
                        : 'Se registró tu progreso automáticamente.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isAllCompleted)
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  CertificateViewerModal.show(context, widget.course);
                },
                icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB800), size: 16),
                label: const Text(
                  'Certificado',
                  style: TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              )
            else
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  final next = vm.getNextLesson(lesson);
                  if (next != null) {
                    vm.selectLesson(next);
                    _initializeLessonMedia(next);
                  }
                },
                child: const Text('Siguiente', style: TextStyle(color: Color(0xFF00BFA5), fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  void _shareLesson(Lesson? lesson) {
    final title = lesson?.title ?? widget.course.title;
    final shareMessage = '🎓 ¡Estoy estudiando "$title" en el curso "${widget.course.title}" de Master Academy!\nDescarga la app y aprende con nosotros: https://masteracademy.mx/cursos/${widget.course.id}';
    Share.share(
      shareMessage,
      subject: 'Clase: $title - Master Academy',
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controlsHideTimer?.cancel();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    try {
      _webViewController?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    _webViewController = null;
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final learningVm = context.watch<LearningViewModel>();
    final downloadVm = context.watch<DownloadViewModel>();
    final courseVm = context.watch<CourseViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeLesson = learningVm.activeLesson;

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // Reactivar automáticamente la reproducción cuando se detecta conexión
    if (_isOfflineNotDownloaded && !courseVm.isOffline && activeLesson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOfflineNotDownloaded && !courseVm.isOffline) {
          _initializeLessonMedia(activeLesson);
        }
      });
    }

    // Desactivar automáticamente la reproducción cuando se pierde la conexión
    if (!_isOfflineNotDownloaded && courseVm.isOffline && activeLesson != null && !activeLesson.isReading) {
      final isLocallyDownloaded = downloadVm.isDownloaded(activeLesson.id);
      if (!isLocallyDownloaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isOfflineNotDownloaded && courseVm.isOffline) {
            setState(() {
              _isLoadingVideo = false;
              _isUsingNativeVideo = false;
              _isWebVideo = false;
              _isPlayingOfflineDownloaded = false;
              _isOfflineNotDownloaded = true;
              _hasVideoPlaybackError = false;
            });
          }
        });
      }
    }

    final scaffold = Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${learningVm.progressPercentage.toStringAsFixed(0)}% completado • ${learningVm.completedLessonsCount}/${learningVm.totalLessonsCount} clases',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (activeLesson != null)
                  _buildDownloadButton(context, downloadVm, activeLesson),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, size: 24),
                  tooltip: 'Pantalla completa',
                  onPressed: _toggleFullscreen,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Compartir clase',
                  onPressed: () => _shareLesson(activeLesson),
                ),
              ],
            ),
      body: _isFullscreen
          ? Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: _buildVideoPlayerSection(activeLesson, isDark),
            )
          : (learningVm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : (isLandscape
                  ? _buildLandscapeLayout(learningVm, activeLesson, isDark)
                  : _buildPortraitLayout(learningVm, activeLesson, isDark))),
      bottomNavigationBar: (!isLandscape && !_isFullscreen && activeLesson != null)
          ? _buildPlayerStatusBar(learningVm, activeLesson, isDark)
          : null,
    );

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) {
          _toggleFullscreen();
        }
      },
      child: scaffold,
    );
  }

  Widget _buildPortraitLayout(LearningViewModel learningVm, Lesson? activeLesson, bool isDark) {
    final bool isReadingOnly = activeLesson != null && activeLesson.isReading && !activeLesson.isMixed;

    return Column(
      children: [
        // Visual Media Player (se oculta automáticamente en clases exclusivamente de lectura)
        if (!isReadingOnly)
          _buildVideoPlayerSection(activeLesson, isDark),

        // Linear Progress Bar
        LinearProgressIndicator(
          value: learningVm.progressPercentage / 100.0,
          backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
          minHeight: isReadingOnly ? 3 : 4,
        ),

        // Tabs for Syllabus, Article Content and Resources
        Expanded(
          child: _buildTabsSection(learningVm, activeLesson, isDark, isLandscape: false),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(LearningViewModel learningVm, Lesson? activeLesson, bool isDark) {
    final bool isReadingOnly = activeLesson != null && activeLesson.isReading && !activeLesson.isMixed;
    if (isReadingOnly) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: learningVm.progressPercentage / 100.0,
            backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
            minHeight: 3,
          ),
          Expanded(
            child: _buildTabsSection(learningVm, activeLesson, isDark, isLandscape: true),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Columna Izquierda: Video Player + Progreso + Controles rápidos
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: _buildVideoPlayerSection(activeLesson, isDark),
                ),
              ),
              LinearProgressIndicator(
                value: learningVm.progressPercentage / 100.0,
                backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
                minHeight: 3,
              ),
              if (activeLesson != null)
                _buildLandscapePlayerControls(learningVm, activeLesson, isDark),
            ],
          ),
        ),

        // Divisor vertical
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),

        // Columna Derecha: Temario, Lectura y Recursos
        Expanded(
          flex: 4,
          child: Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: _buildTabsSection(learningVm, activeLesson, isDark, isLandscape: true),
          ),
        ),
      ],
    );
  }

  Widget _buildTabsSection(LearningViewModel learningVm, Lesson? activeLesson, bool isDark, {bool isLandscape = false}) {
    final bool isReadingOnly = activeLesson != null && activeLesson.isReading && !activeLesson.isMixed;
    return DefaultTabController(
      key: ValueKey('learning_tabs_${widget.course.id}'),
      length: 3,
      initialIndex: isReadingOnly ? 1 : 0,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white60 : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isLandscape ? 11 : 12),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: isLandscape ? 11 : 12),
            tabs: [
              Tab(
                icon: Icon(Icons.list_alt_rounded, size: isLandscape ? 16 : 18),
                text: 'Temario',
                iconMargin: const EdgeInsets.only(bottom: 2),
              ),
              Tab(
                icon: Icon(Icons.menu_book_rounded, size: isLandscape ? 16 : 18),
                text: 'Lectura',
                iconMargin: const EdgeInsets.only(bottom: 2),
              ),
              Tab(
                icon: Icon(Icons.folder_open_rounded, size: isLandscape ? 16 : 18),
                text: 'Recursos',
                iconMargin: const EdgeInsets.only(bottom: 2),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSyllabusList(learningVm, isDark),
                _buildLessonContentTab(activeLesson, isDark, learningVm),
                _buildResourcesTab(activeLesson, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapePlayerControls(LearningViewModel learningVm, Lesson activeLesson, bool isDark) {
    final nextLesson = learningVm.getNextLesson(activeLesson);
    final isAllCompleted = learningVm.progressPercentage >= 100.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Row(
        children: [
          // Toggle completada
          InkWell(
            onTap: () async {
              final courseVm = context.read<CourseViewModel>();
              final newStatus = await learningVm.toggleLessonCompletion(activeLesson, courseId: widget.course.id);
              if (mounted) {
                courseVm.updateCourseProgress(widget.course.id, learningVm.progressPercentage);
                if (newStatus) {
                  _showLessonCompletedCelebration(activeLesson);
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: activeLesson.isCompleted
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: activeLesson.isCompleted
                      ? const Color(0xFF10B981).withOpacity(0.6)
                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activeLesson.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: activeLesson.isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.grey.shade600),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    activeLesson.isCompleted ? 'Completada' : 'Marcar lista',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: activeLesson.isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white70 : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Título lección
          Expanded(
            child: Text(
              activeLesson.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Siguiente o Certificado
          if (nextLesson != null)
            ElevatedButton.icon(
              onPressed: () => learningVm.selectLesson(nextLesson),
              icon: const Icon(Icons.skip_next_rounded, size: 16),
              label: const Text('Siguiente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          else if (isAllCompleted)
            ElevatedButton.icon(
              onPressed: () => CertificateViewerModal.show(context, widget.course),
              icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF0F172A)),
              label: const Text('Certificado', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerSection(Lesson? lesson, bool isDark) {
    if (lesson == null) {
      return _buildLoadingOrEmptyPlayer(lesson, isDark);
    }
    if (lesson.isReading) {
      return _buildArticleReaderHeader(lesson, isDark);
    }
    if (_isLoadingVideo) {
      return _buildLoadingOrEmptyPlayer(lesson, isDark);
    }
    if (_isWebVideo && _webViewController != null) {
      return _buildWebVideoPlayer(lesson);
    }
    if (_isOfflineNotDownloaded) {
      return _buildOfflineNotDownloadedPlaceholder(lesson, isDark);
    }
    if (_hasVideoPlaybackError) {
      return _buildVideoErrorPlaceholder(lesson, isDark);
    }
    if (_isUsingNativeVideo && _videoController != null && _videoController!.value.isInitialized) {
      return _buildNativeVideoPlayer(lesson);
    }
    return _buildLoadingOrEmptyPlayer(lesson, isDark);
  }

  Widget _buildWebVideoPlayer(Lesson? lesson) {
    final controller = _webViewController;
    if (controller == null) {
      return _buildLoadingOrEmptyPlayer(lesson, Theme.of(context).brightness == Brightness.dark);
    }
    final rawUrl = lesson?.videoUrl?.trim() ?? '';
    final ytId = _extractYouTubeId(rawUrl);

    final playerContent = Container(
      color: Colors.black,
      child: WebViewWidget(
        key: const ValueKey('player_webview'),
        controller: controller,
      ),
    );

    if (_isFullscreen) {
      return Stack(
        children: [
          Positioned.fill(child: playerContent),
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleFullscreen,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Salir de pantalla completa',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (ytId != null && ytId.isNotEmpty)
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.parse('https://www.youtube.com/watch?v=$ytId');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Abrir en YouTube',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(child: playerContent),
          if (ytId != null && ytId.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.parse('https://www.youtube.com/watch?v=$ytId');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white38, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'YouTube',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleReaderHeader(Lesson lesson, bool isDark) {
    final playerContent = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF00BFA5)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          lesson.isMixed ? 'CLASE MIXTA (VIDEO + GUÍA)' : 'LECTURA DE ESPECIALIZACIÓN',
                          style: const TextStyle(
                            color: Color(0xFF00BFA5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (lesson.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'Completada',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lesson.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 5),
              Text(
                lesson.formattedDuration,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.swipe_left_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Consulta la pestaña "Lectura / Guía" abajo',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (_isFullscreen) {
      return SizedBox.expand(child: playerContent);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: playerContent);
  }

  Widget _buildLessonContentTab(Lesson? lesson, bool isDark, LearningViewModel learningVm) {
    if (lesson == null) {
      return Center(
        child: Text(
          'Selecciona una lección para leer su contenido.',
          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
      );
    }

    final hasCustomText = lesson.description != null && lesson.description!.trim().isNotEmpty;
    final textContent = hasCustomText
        ? lesson.description!.trim()
        : 'En esta lección profundizaremos en los fundamentos y aplicaciones prácticas de "${lesson.title}". Revisa los materiales, sigue la metodología y realiza los ejercicios propuestos para asegurar el dominio de los conceptos.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lesson.isReading
                      ? const Color(0xFF00BFA5).withOpacity(0.12)
                      : (lesson.isMixed ? const Color(0xFF6366F1).withOpacity(0.12) : AppColors.primary.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      lesson.isReading
                          ? Icons.menu_book_rounded
                          : (lesson.isMixed ? Icons.auto_stories_rounded : Icons.play_circle_outline_rounded),
                      size: 14,
                      color: lesson.isReading
                          ? const Color(0xFF00BFA5)
                          : (lesson.isMixed ? const Color(0xFF6366F1) : AppColors.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lesson.isReading
                          ? 'Lección de Lectura'
                          : (lesson.isMixed ? 'Lección Mixta (Video + Guía)' : 'Apuntes de la Clase en Video'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: lesson.isReading
                            ? const Color(0xFF00BFA5)
                            : (lesson.isMixed ? const Color(0xFF6366F1) : AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                lesson.formattedDuration,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            lesson.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFB800), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Objetivo y Contenido Clave',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  textContent,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Puntos a Recordar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGuideBullet(
                  'Comprender la base teórica y su impacto en proyectos reales.',
                  isDark,
                ),
                const SizedBox(height: 6),
                _buildGuideBullet(
                  'Tomar notas clave en la pestaña "Recursos y Notas" para afianzar el aprendizaje.',
                  isDark,
                ),
                const SizedBox(height: 6),
                _buildGuideBullet(
                  'Al finalizar, pulsa el botón de abajo para registrar tu avance en la plataforma.',
                  isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final courseVm = context.read<CourseViewModel>();
                final newStatus = await learningVm.toggleLessonCompletion(lesson, courseId: widget.course.id);
                if (mounted) {
                  courseVm.updateCourseProgress(widget.course.id, learningVm.progressPercentage);
                  if (newStatus) {
                    _showLessonCompletedCelebration(lesson);
                  }
                }
              },
              icon: Icon(
                lesson.isCompleted ? Icons.check_circle_rounded : Icons.task_alt_rounded,
                color: Colors.white,
              ),
              label: Text(
                lesson.isCompleted ? 'Lección Completada ✓ (Toca para desmarcar)' : 'Marcar Lección como Completada',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: lesson.isCompleted ? const Color(0xFF10B981) : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildGuideBullet(String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF00BFA5) : AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNativeVideoPlayer(Lesson? lesson) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingOrEmptyPlayer(lesson, Theme.of(context).brightness == Brightness.dark);
    }

    final playerContent = Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.isInitialized && controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (_isPlayingOfflineDownloaded)
            Positioned(
              top: _isFullscreen ? 24 : 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Descargado (Offline)',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (_showControls)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, val, _) {
                return _buildControlsOverlay(
                  title: lesson?.title ?? '',
                  isPlaying: val.isPlaying,
                  position: val.position,
                  duration: val.duration,
                  onPlayPause: () {
                    if (val.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  onSeek: (pos) => controller.seekTo(pos),
                );
              },
            ),
        ],
      ),
    );

    if (_isFullscreen) {
      return SizedBox.expand(child: playerContent);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: playerContent,
    );
  }

  Widget _buildOfflineNotDownloadedPlaceholder(Lesson? lesson, bool isDark) {
    final playerContent = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Video no disponible sin conexión',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Esta clase no está descargada en tu dispositivo. Descárgala previamente cuando tengas internet para verla offline.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final courseVm = Provider.of<CourseViewModel>(context, listen: false);
                      await courseVm.checkConnectivity();
                      if (mounted && lesson != null) {
                        _initializeLessonMedia(lesson);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF00BFA5)),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(color: Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00BFA5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SavedLessonsScreen.route(),
                      );
                    },
                    icon: const Icon(Icons.folder_special_rounded, size: 14, color: Colors.white),
                    label: const Text(
                      'Ver Descargas',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (_isFullscreen) {
      return SizedBox.expand(child: playerContent);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: playerContent,
    );
  }


  Widget _buildVideoErrorPlaceholder(Lesson? lesson, bool isDark) {
    final rawUrl = lesson?.videoUrl?.trim() ?? '';

    final playerContent = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No se pudo reproducir el video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'El enlace o formato del video no es compatible directamente con el reproductor móvil.',
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      if (lesson != null) {
                        _initializeLessonMedia(lesson);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Reintentar', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  if (rawUrl.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(rawUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                      label: const Text('Abrir enlace', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (_isFullscreen) {
      return SizedBox.expand(child: playerContent);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: playerContent);
  }

  Widget _buildLoadingOrEmptyPlayer(Lesson? lesson, bool isDark) {
    final playerContent = Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: Color(0xFF00BFA5),
                strokeWidth: 3.5,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Cargando clase...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    if (_isFullscreen) {
      return SizedBox.expand(child: playerContent);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: playerContent,
    );
  }

  Widget _buildControlsOverlay({
    required String title,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required VoidCallback onPlayPause,
    required Function(Duration) onSeek,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.55),
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Top Title
          Positioned(
            top: _isFullscreen ? 18 : 10,
            left: 14,
            right: 140,
            child: Row(
              children: [
                if (_isFullscreen) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _toggleFullscreen,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Center Play / 10s Rewind / 10s Fast-Forward
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 30),
                  onPressed: () {
                    final newPos = position - const Duration(seconds: 10);
                    onSeek(newPos < Duration.zero ? Duration.zero : newPos);
                  },
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 30),
                  onPressed: () {
                    final newPos = position + const Duration(seconds: 10);
                    onSeek(newPos > duration ? duration : newPos);
                  },
                ),
              ],
            ),
          ),

          // Bottom Timeline Scrubber & Speed Controls
          Positioned(
            bottom: _isFullscreen ? 16 : 4,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (val) {
                      final targetMs = (val * duration.inMilliseconds).toInt();
                      onSeek(Duration(milliseconds: targetMs));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Spacer(),
                      // Speed Selector
                      GestureDetector(
                        onTap: () {
                          final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
                          final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
                          final newSpeed = speeds[nextIndex];
                          setState(() => _playbackSpeed = newSpeed);
                          _videoController?.setPlaybackSpeed(newSpeed);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Interactive Fullscreen Button
                      GestureDetector(
                        onTap: _toggleFullscreen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildDownloadButton(BuildContext context, DownloadViewModel downloadVm, Lesson lesson) {
    final rawUrl = lesson.videoUrl?.trim() ?? '';
    final isYouTubeOrDrive = _extractYouTubeId(rawUrl) != null ||
        _extractGoogleDriveId(rawUrl) != null ||
        rawUrl.contains('youtube.com') ||
        rawUrl.contains('youtu.be') ||
        rawUrl.contains('drive.google.com') ||
        rawUrl.contains('docs.google.com');

    // Si el video es por medio de URL como YouTube o Google Drive, desaparece el botón de descarga
    if (isYouTubeOrDrive) {
      return const SizedBox.shrink();
    }

    final isDownloaded = downloadVm.isDownloaded(lesson.id);
    final isDownloading = downloadVm.isDownloading(lesson.id);
    final progress = downloadVm.getProgress(lesson.id);

    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 2.5,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
          ),
        ),
      );
    }

    if (isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.download_done_rounded, color: Color(0xFF10B981), size: 22),
        tooltip: 'Descargado localmente (Offline)',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta clase está guardada en tu dispositivo para reproducción offline.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }

    if (lesson.isReading || (lesson.videoUrl == null || lesson.videoUrl!.trim().isEmpty)) {
      return IconButton(
        icon: Icon(
          isDownloaded ? Icons.download_done_rounded : Icons.menu_book_rounded,
          color: const Color(0xFF00BFA5),
          size: 22,
        ),
        tooltip: isDownloaded ? 'Lectura guardada offline' : 'Guardar lectura para offline',
        onPressed: () async {
          if (isDownloaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Esta clase de lectura está guardada en tu dispositivo para estudio offline.'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Guardando "${lesson.title}" para offline...'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );

          final success = await downloadVm.downloadReadingLesson(
            lessonId: lesson.id,
            courseId: widget.course.id,
            courseTitle: widget.course.title,
            lessonTitle: lesson.title,
            thumbnail: widget.course.thumbnail,
          );
          if (success) {
            await _loadDownloadedLessonIds();
            try {
              final storage = sl<FlutterSecureStorage>();
              final learningVm = context.read<LearningViewModel>();
              if (learningVm.sections.isNotEmpty) {
                final rawList = learningVm.sections.map((s) => {
                  'id': s.id,
                  'title': s.title,
                  'order': s.order,
                  'children': s.lessons.map((l) => {
                    'id': l.id,
                    'course_syllabus_id': s.id,
                    'title': l.title,
                    'description': l.description,
                    'video_url': l.videoUrl,
                    'duration_seconds': l.durationSeconds,
                    'order': l.order,
                    'is_completed': l.isCompleted,
                    'is_free_preview': l.isFreePreview,
                    'type': l.type,
                  }).toList(),
                }).toList();
                final jsonStr = jsonEncode(rawList);
                await storage.write(key: 'user_course_syllabi_cache_${widget.course.id}', value: jsonStr);
                final cleanId = widget.course.id.toString().replaceAll(RegExp(r'[^0-9]'), '');
                if (cleanId.isNotEmpty) {
                  await storage.write(key: 'user_course_syllabi_cache_$cleanId', value: jsonStr);
                }
              }
            } catch (_) {}
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? '¡"${lesson.title}" guardada exitosamente!' : 'No se pudo guardar la lección.'),
                backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_for_offline_outlined, size: 22),
      tooltip: 'Descargar para ver offline',
      onPressed: () async {
        final videoUrl = lesson.videoUrl!.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Descargando "${lesson.title}" para offline...'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );

        final success = await downloadVm.downloadLesson(
          lessonId: lesson.id,
          courseId: widget.course.id,
          courseTitle: widget.course.title,
          lessonTitle: lesson.title,
          videoUrl: videoUrl,
          thumbnail: widget.course.thumbnail,
        );
        if (success) {
          await _loadDownloadedLessonIds();
          try {
            final storage = sl<FlutterSecureStorage>();
            final learningVm = context.read<LearningViewModel>();
            if (learningVm.sections.isNotEmpty) {
              final rawList = learningVm.sections.map((s) => {
                'id': s.id,
                'title': s.title,
                'order': s.order,
                'children': s.lessons.map((l) => {
                  'id': l.id,
                  'course_syllabus_id': s.id,
                  'title': l.title,
                  'description': l.description,
                  'video_url': l.videoUrl,
                  'duration_seconds': l.durationSeconds,
                  'order': l.order,
                  'is_completed': l.isCompleted,
                  'is_free_preview': l.isFreePreview,
                  'type': l.type,
                }).toList(),
              }).toList();
              final jsonStr = jsonEncode(rawList);
              await storage.write(key: 'user_course_syllabi_cache_${widget.course.id}', value: jsonStr);
              final cleanId = widget.course.id.toString().replaceAll(RegExp(r'[^0-9]'), '');
              if (cleanId.isNotEmpty) {
                await storage.write(key: 'user_course_syllabi_cache_$cleanId', value: jsonStr);
              }
            }
          } catch (_) {}
          if (mounted && lesson.id == context.read<LearningViewModel>().activeLesson?.id) {
            _initializeLessonMedia(lesson);
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '¡"${lesson.title}" guardada exitosamente!' : 'No se pudo guardar la lección offline.'),
              backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  Widget _buildSyllabusList(LearningViewModel learningVm, bool isDark) {
    if (learningVm.sections.isEmpty) {
      return Center(
        child: Text(
          'No hay lecciones registradas para este curso.',
          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: learningVm.sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = learningVm.sections[sectionIndex];

        final bool isSectionCompleted = section.lessons.isNotEmpty && section.lessons.every((l) => l.isCompleted);
        final int completedLessonsCount = section.lessons.where((l) => l.isCompleted).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: section.isFinalCertification
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB))
                : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: section.isFinalCertification
                  ? const Color(0xFFF59E0B)
                  : (isDark ? AppColors.darkBorder : AppColors.border),
              width: section.isFinalCertification ? 1.5 : 1.0,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('section_${section.id}'),
              initiallyExpanded: _sectionExpandedState[section.id] ?? (sectionIndex == 0 || section.isFinalCertification),
              onExpansionChanged: (isExpanded) {
                _sectionExpandedState[section.id] = isExpanded;
              },
              iconColor: section.isFinalCertification
                  ? const Color(0xFFF59E0B)
                  : (isSectionCompleted ? const Color(0xFF10B981) : AppColors.primary),
              collapsedIconColor: section.isFinalCertification
                  ? const Color(0xFFF59E0B)
                  : (isSectionCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white54 : AppColors.textMuted)),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: section.isFinalCertification
                      ? const Color(0xFFF59E0B).withOpacity(0.15)
                      : (isSectionCompleted
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : (isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  section.isFinalCertification
                      ? Icons.workspace_premium_rounded
                      : (isSectionCompleted ? Icons.check_circle_rounded : Icons.folder_open_rounded),
                  size: 16,
                  color: section.isFinalCertification
                      ? const Color(0xFFF59E0B)
                      : (isSectionCompleted ? const Color(0xFF10B981) : AppColors.primary),
                ),
              ),
              title: Text(
                section.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: section.isFinalCertification
                      ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                      : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
              subtitle: Text(
                section.isFinalCertification
                    ? 'Evaluación Global obligatoria para Diploma Oficial'
                    : '${section.lessons.length} clases • $completedLessonsCount completadas',
                style: TextStyle(
                  fontSize: 12,
                  color: section.isFinalCertification
                      ? (isDark ? Colors.amber.shade200 : Colors.amber.shade800)
                      : (isSectionCompleted
                          ? const Color(0xFF10B981)
                          : (isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                ),
              ),
              children: [
                ...section.lessons.map((lesson) {
                final isCurrent = learningVm.activeLesson?.id == lesson.id;

                return InkWell(
                  onTap: () {
                    learningVm.selectLesson(lesson);
                    _initializeLessonMedia(lesson);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isCurrent
                        ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.08)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        // Completion status indicator (Tap to toggle/accredit)
                        InkWell(
                          onTap: () async {
                            final learningVm = context.read<LearningViewModel>();
                            final courseVm = context.read<CourseViewModel>();
                            final newStatus = await learningVm.toggleLessonCompletion(lesson, courseId: widget.course.id);
                            if (mounted) {
                              courseVm.updateCourseProgress(widget.course.id, learningVm.progressPercentage);
                              if (newStatus && lesson.id == learningVm.activeLesson?.id) {
                                _showLessonCompletedCelebration(lesson);
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lesson.isCompleted
                                    ? const Color(0xFF10B981)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: lesson.isCompleted
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.white38 : AppColors.border),
                                  width: 2,
                                ),
                              ),
                              child: lesson.isCompleted
                                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Lesson title and time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lesson.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isCurrent
                                      ? AppColors.primary
                                      : (isDark ? Colors.white : AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    lesson.isReading
                                        ? Icons.menu_book_rounded
                                        : (lesson.isMixed ? Icons.smart_display_rounded : Icons.play_circle_outline_rounded),
                                    size: 11,
                                    color: lesson.isReading
                                        ? const Color(0xFF00BFA5)
                                        : (lesson.isMixed ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${lesson.formattedDuration} • ${lesson.isCompleted ? 'Acreditada' : 'Pendiente'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: lesson.isCompleted
                                          ? const Color(0xFF10B981)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                    ),
                                  ),
                                  if (_downloadedLessonIds.contains(lesson.id)) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download_done_rounded, size: 10, color: Color(0xFF10B981)),
                                          SizedBox(width: 2),
                                          Text(
                                            'Offline',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (context.watch<CourseViewModel>().isOffline) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.cloud_off_rounded, size: 10, color: Colors.amber),
                                          SizedBox(width: 2),
                                          Text(
                                            'Sin descargar',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const Icon(Icons.equalizer_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              if (section.evaluation != null)
                _buildPlayerEvaluationTile(section.evaluation!, isDark),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildPlayerEvaluationTile(Quiz quiz, bool isDark) {
    return FutureBuilder<bool>(
      future: sl<QuizService>().hasPassed(quiz.id),
      builder: (context, snapshot) {
        final bool isPassed = snapshot.data == true;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  quiz: quiz,
                  course: widget.course,
                  onCompleted: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: quiz.isFinal
                  ? (isDark ? const Color(0xFF0AB39C).withOpacity(0.12) : const Color(0xFFF0FDF4))
                  : (isDark ? const Color(0xFF1E293B).withOpacity(0.4) : Colors.grey.shade50),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isPassed
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : (quiz.isFinal
                            ? const Color(0xFFF59E0B).withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.12)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassed
                        ? Icons.check_circle_rounded
                        : (quiz.isFinal ? Icons.workspace_premium_rounded : Icons.assignment_turned_in_rounded),
                    size: 16,
                    color: isPassed
                        ? const Color(0xFF10B981)
                        : (quiz.isFinal ? const Color(0xFFD97706) : AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: quiz.isFinal
                                  ? const Color(0xFFF59E0B).withOpacity(0.12)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quiz.isFinal ? 'EXAMEN FINAL DIPLOMA' : 'EVALUACIÓN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: quiz.isFinal ? const Color(0xFFD97706) : AppColors.primary,
                              ),
                            ),
                          ),
                          if (isPassed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'APTO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        quiz.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${quiz.questions.length} preguntas • Mínimo ${quiz.passingScore}% requerida',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? Colors.white38 : AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResourcesTab(Lesson? lesson, bool isDark) {
    if (lesson == null) {
      return Center(
        child: Text(
          'Selecciona una lección para ver sus recursos y notas.',
          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
      );
    }

    final resources = lesson.resources;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Descargas & Material
          Row(
            children: [
              const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Materiales de la Clase (${resources.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (resources.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: isDark ? Colors.white54 : AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esta clase no cuenta con archivos descargables complementarios.',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            ...resources.map((res) {
              IconData fileIcon = Icons.file_present_rounded;
              Color iconColor = AppColors.primary;
              final type = (res.fileType ?? '').toLowerCase();
              if (type.contains('pdf')) {
                fileIcon = Icons.picture_as_pdf_rounded;
                iconColor = const Color(0xFFEF4444);
              } else if (type.contains('xls') || type.contains('sheet')) {
                fileIcon = Icons.table_chart_rounded;
                iconColor = const Color(0xFF10B981);
              } else if (type.contains('zip') || type.contains('rar')) {
                fileIcon = Icons.folder_zip_rounded;
                iconColor = const Color(0xFFF59E0B);
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ResourceViewerModal.show(context, res, lessonTitle: lesson.title),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.12),
                          child: Icon(fileIcon, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                res.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Formato: ${(res.fileType ?? 'Material').toUpperCase()} • Toca para abrir',
                                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'Visualizar material',
                          onPressed: () => ResourceViewerModal.show(context, res, lessonTitle: lesson.title),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined, color: Colors.grey, size: 20),
                          tooltip: 'Descargar archivo',
                          onPressed: () {
                            DownloadDestinationModal.show(
                              context,
                              fileName: '${res.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.${res.fileType?.toLowerCase() == 'pdf' ? 'pdf' : (res.fileType?.toLowerCase() ?? 'pdf')}',
                              fileTitle: res.title,
                              fileType: res.fileType?.toUpperCase() ?? 'PDF',
                              textContent: '===================================================\n'
                                  'MASTER ACADEMY - RECURSO DE CLASE\n'
                                  '===================================================\n\n'
                                  'Material: ${res.title}\n'
                                  'Clase: ${lesson.title}\n'
                                  'Curso: ${widget.course.title}\n'
                                  'Tipo: ${res.fileType ?? "PDF"}\n'
                                  'URL: ${res.fileUrl ?? "Local"}\n\n'
                                  'Material educativo provisto por Master Academy.\n'
                                  'Todos los derechos reservados.',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // Section: Mis Notas de la Clase
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Mis Notas Personales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(context, StudentNotebookScreen.route()),
                icon: const Icon(Icons.notes_rounded, size: 14, color: AppColors.primary),
                label: const Text('Ver todas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), minimumSize: const Size(0, 26)),
              ),
              if (_noteSavedSuccessfully)
                const Row(
                  children: [
                    SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Guardado',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe tus apuntes clave para esta clase. Se guardarán en tu dispositivo automáticamente.',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _notesController,
              maxLines: 5,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej: Recordar revisar los conceptos de prevención y aplicar el checklist en el paso 3...',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingNote ? null : () => _saveLessonNotes(lesson.id),
              icon: _isSavingNote
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: Text(
                _isSavingNote ? 'Guardando...' : 'Guardar Apuntes',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Interacción con el instructor y Calificación
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    InstructorInquiryModal.show(
                      context,
                      courseId: widget.course.id,
                      courseTitle: widget.course.title,
                      instructorName: widget.course.instructor,
                      lessonTitle: lesson.title,
                    );
                  },
                  icon: const Icon(Icons.school_outlined, size: 16, color: AppColors.primary),
                  label: const Text('Duda al Docente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final isEnrolled = context.read<CourseViewModel>().isCourseEnrolled(widget.course.id);
                    if (!isEnrolled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('Solo los estudiantes inscritos pueden calificar este curso.'),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return;
                    }
                    CourseRatingModal.show(
                      context,
                      courseId: widget.course.id,
                      courseTitle: widget.course.title,
                      isEnrolled: isEnrolled,
                    );
                  },
                  icon: const Icon(Icons.star_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                  label: const Text('Calificar Curso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bandeja de comentarios tipo YouTube
          YoutubeStyleCommentsSection(
            courseId: widget.course.id,
            lessonId: lesson.id,
            courseTitle: widget.course.title,
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildPlayerStatusBar(LearningViewModel learningVm, Lesson activeLesson, bool isDark) {
    final nextLesson = learningVm.getNextLesson(activeLesson);
    final isAllCompleted = learningVm.progressPercentage >= 100.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Status Completion Pill
            InkWell(
              onTap: () async {
                final learningVm = context.read<LearningViewModel>();
                final courseVm = context.read<CourseViewModel>();
                final newStatus = await learningVm.toggleLessonCompletion(activeLesson, courseId: widget.course.id);
                if (mounted) {
                  courseVm.updateCourseProgress(widget.course.id, learningVm.progressPercentage);
                  if (newStatus) {
                    _showLessonCompletedCelebration(activeLesson);
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activeLesson.isCompleted
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activeLesson.isCompleted
                        ? const Color(0xFF10B981).withOpacity(0.6)
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activeLesson.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: activeLesson.isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.grey.shade600),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      activeLesson.isCompleted ? 'Completada' : 'Marcar lista',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activeLesson.isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white70 : AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Next lesson preview text
            if (nextLesson != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIGUIENTE',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        nextLesson.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
            else if (isAllCompleted)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '¡Curso 100% Finalizado!',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFFB800), fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              const Spacer(),

            // Action Button
            if (isAllCompleted)
              ElevatedButton.icon(
                onPressed: () => CertificateViewerModal.show(context, widget.course),
                icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF0F172A)),
                label: const Text('Certificado', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 1,
                ),
              )
            else if (nextLesson != null)
              ElevatedButton.icon(
                onPressed: () {
                  learningVm.selectLesson(nextLesson);
                  _initializeLessonMedia(nextLesson);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                label: const Text('Siguiente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
