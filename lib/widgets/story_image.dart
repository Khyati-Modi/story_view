import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

/// Utitlity to load image (gif, png, jpg, etc) media just once. Resource is
/// cached to disk with default configurations of [DefaultCacheManager].
class ImageLoader {
  ui.Codec? frames;

  String? url;
  String? file;

  Map<String, String>? requestHeaders;

  LoadState state = LoadState.loading; // by default

  ImageLoader({this.url, this.file, this.requestHeaders});

  /// Load image from disk cache first, if not found then load from network.
  /// `onComplete` is called when [imageBytes] become available.
  void loadImage(VoidCallback onComplete) {
    if (frames != null) {
      state = LoadState.success;
      onComplete();
    }

    if (url == null) {
      final imageBytes = new File(file!).readAsBytesSync();
      state = LoadState.success;
      PaintingBinding.instance!.instantiateImageCodec(imageBytes).then((codec) {
        frames = codec;
        onComplete();
      }, onError: (error) {
        state = LoadState.failure;
        onComplete();
      });
    } else {
      final fileStream =
          DefaultCacheManager().getFileStream(url!, headers: requestHeaders);

      fileStream.listen(
        (fileResponse) {
          if (!(fileResponse is FileInfo)) return;
          // the reason for this is that, when the cache manager fetches
          // the image again from network, the provided `onComplete` should
          // not be called again
          if (frames != null) {
            return;
          }

          final imageBytes = (fileResponse as FileInfo).file.readAsBytesSync();

          state = LoadState.success;

          PaintingBinding.instance!.instantiateImageCodec(imageBytes).then(
              (codec) {
            frames = codec;
            onComplete();
          }, onError: (error) {
            state = LoadState.failure;
            onComplete();
          });
        },
        onError: (error) {
          state = LoadState.failure;
          onComplete();
        },
      );
    }
  }
}

/// Widget to display animated gifs or still images. Shows a loader while image
/// is being loaded. Listens to playback states from [controller] to pause and
/// forward animated media.
class StoryImage extends StatefulWidget {
  final ImageLoader imageLoader;

  final BoxFit? fit;

  final StoryController? controller;

  StoryImage(
    this.imageLoader, {
    Key? key,
    this.controller,
    this.fit,
  }) : super(key: key ?? UniqueKey());

  /// Use this shorthand to fetch images/gifs from the provided [url]
  factory StoryImage.url({
    String? url,
    String? file,
    StoryController? controller,
    Map<String, String>? requestHeaders,
    BoxFit fit = BoxFit.fitWidth,
    Key? key,
  }) {
    return StoryImage(
        ImageLoader(
          url: url,
          file: file,
          requestHeaders: requestHeaders,
        ),
        controller: controller,
        fit: fit,
        key: key);
  }

  @override
  State<StatefulWidget> createState() => StoryImageState();
}

class StoryImageState extends State<StoryImage> {
  ui.Image? currentFrame;

  Timer? _timer;

  StreamSubscription<PlaybackState>? _streamSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      _streamSubscription =
          widget.controller!.playbackNotifier.listen((playbackState) {
        // for the case of gifs we need to pause/play
        if (widget.imageLoader.frames == null) {
          return;
        }

        if (playbackState == PlaybackState.pause) {
          _timer?.cancel();
        } else {
          forward();
        }
      });
    }

    widget.controller?.pause();

    widget.imageLoader.loadImage(() async {
      if (mounted) {
        if (widget.imageLoader.state == LoadState.success) {
          widget.controller?.play();
          forward();
        } else {
          // refresh to show error
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamSubscription?.cancel();

    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void forward() async {
    _timer?.cancel();

    if (widget.controller != null &&
        widget.controller!.playbackNotifier.stream.value ==
            PlaybackState.pause) {
      return;
    }

    final nextFrame = await widget.imageLoader.frames!.getNextFrame();

    currentFrame = nextFrame.image;

    if (nextFrame.duration > Duration(milliseconds: 0)) {
      _timer = Timer(nextFrame.duration, forward);
    }

    setState(() {});
  }

  Widget getContentView() {
    switch (widget.imageLoader.state) {
      case LoadState.success:
        return RawImage(
          image: currentFrame,
          fit: widget.fit,
        );
      case LoadState.failure:
        return Center(
            child: Text(
          "Image failed to load.",
          style: TextStyle(
            color: Colors.white,
          ),
        ));
      default:
        return Center(
          child: Container(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: getContentView(),
    );
  }
}
