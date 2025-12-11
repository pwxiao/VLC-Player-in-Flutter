import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({Key? key}) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen>
    with TickerProviderStateMixin {
  late VlcPlayerController vlcController;

  late AnimationController _scaleVideoAnimationController;
  Animation<double> _scaleVideoAnimation =
      const AlwaysStoppedAnimation<double>(1.0);
  double?  _targetVideoScale;

  // Cache value for later usage at the end of a scale-gesture
  double _lastZoomGestureScale = 1.0;

  // 新增：视频URL变量
  String _currentVideoURL =
      "https://videos.pexels.com/video-files/3640406/3640406-uhd_2560_1440_25fps. mp4";

  @override
  void initState() {
    super.initState();
    _forceLandscape();

    _scaleVideoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 125),
      vsync: this,
    );

    _initializeVideoPlayer(_currentVideoURL);
  }

  // 新增：初始化视频播放器的方法
  void _initializeVideoPlayer(String videoURL) {
    // 清理旧的controller
    if (vlcController != null && vlcController.initialized) {
      vlcController. removeOnInitListener(_stopAutoplay);
      vlcController.stopRendererScanning();
      vlcController.dispose();
    }

    vlcController = VlcPlayerController. network(videoURL, autoPlay: false);
    vlcController.addOnInitListener(_stopAutoplay);
    setState(() {});
  }

  void setTargetNativeScale(double newValue) {
    if (! newValue.isFinite) {
      return;
    }
    _scaleVideoAnimation =
        Tween<double>(begin: 1.0, end: newValue).animate(CurvedAnimation(
      parent:  _scaleVideoAnimationController,
      curve: Curves.easeInOut,
    ));

    if (_targetVideoScale == null) {
      _scaleVideoAnimationController.forward();
    }
    _targetVideoScale = newValue;
  }

  // Workaround the following bugs:
  // https://github.com/s12olid-software/flutter_vlc_player/issues/335
  // https://github.com/solid-software/flutter_vlc_player/issues/336
  Future<void> _stopAutoplay() async {
    await vlcController.pause();
    await vlcController. play();

    await vlcController.setVolume(0);

    await Future.delayed(const Duration(milliseconds: 450), () async {
      await vlcController.pause();
      await vlcController. setTime(0);
      await vlcController.setVolume(100);
    });
  }

  Future<void> _forceLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation. landscapeLeft,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _forcePortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values); // to re-show bars
  }

  // 新增：显示输入对话框
  void _showVideoURLDialog() {
    TextEditingController urlController =
        TextEditingController(text: _currentVideoURL);

    showDialog(
      context:  context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('输入视频链接'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: '请输入视频URL',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions:  [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                String newURL = urlController.text.trim();
                if (newURL.isNotEmpty) {
                  setState(() {
                    _currentVideoURL = newURL;
                  });
                  _initializeVideoPlayer(newURL);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('视频链接已更新')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效的URL')),
                  );
                }
              },
              child:  const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _forcePortrait();

    vlcController.removeOnInitListener(_stopAutoplay);
    vlcController.stopRendererScanning();
    vlcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final videoSize = vlcController.value.size;
    if (videoSize.width > 0) {
      final newTargetScale = screenSize.width /
          (videoSize.width * screenSize.height / videoSize.height);
      setTargetNativeScale(newTargetScale);
    }

    final vlcPlayer = VlcPlayer(
        controller: vlcController,
        aspectRatio: screenSize.width / screenSize.height,
        placeholder: const Center(child: CircularProgressIndicator()));

    return Scaffold(
        body: Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () async {
          var isPlaying = await vlcController.isPlaying();
          if (isPlaying == true) {
            vlcController.pause();
          } else {
            vlcController. play();
          }
        },
        onScaleUpdate: (details) {
          _lastZoomGestureScale = details.scale;
        },
        onScaleEnd: (details) {
          if (_lastZoomGestureScale > 1.0) {
            setState(() {
              // Zoom in
              _scaleVideoAnimationController.forward();
            });
          } else if (_lastZoomGestureScale < 1.0) {
            setState(() {
              // Zoom out
              _scaleVideoAnimationController.reverse();
            });
          }
          _lastZoomGestureScale = 1.0;
        },
        child: Stack(
          children:  [
            Container(
              // Background behind the video
              color: Colors.black,
            ),
            Center(
                child: ScaleTransition(
                    scale: _scaleVideoAnimation,
                    child: AspectRatio(aspectRatio: 16 / 9, child: vlcPlayer))),
          ],
        ),
      ),
    ),
        // 新增：悬浮按钮
        floatingActionButton: FloatingActionButton(
          onPressed: _showVideoURLDialog,
          child: const Icon(Icons.add_link),
        ));
  }
}
