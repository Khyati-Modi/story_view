import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  String? url;
  String? file;

  File? videoFile;

  Map<String, String>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader({
    this.url,
    this.file,
    this.requestHeaders,
  });

  void loadVideo(VoidCallback onComplete) {
    if (videoFile != null) {
      state = LoadState.success;
      onComplete();
    }

    // final fileStream = DefaultCacheManager().getFileStream(this.url,
    //     headers: this.requestHeaders as Map<String, String>?);

    // fileStream.listen((fileResponse) {
    //   if (fileResponse is FileInfo) {
    //     if (this.videoFile == null) {
    //       this.state = LoadState.success;
    //       this.videoFile = fileResponse.file;
    //       onComplete();
    //     }
    //   }
    // });
    if (url == null) {
      state = LoadState.success;
      videoFile = File(file!);
      onComplete();
    } else {
      final fileStream =
          DefaultCacheManager().getFileStream(url!, headers: requestHeaders);
      fileStream.listen((fileResponse) {
        if (fileResponse is FileInfo) {
          if (videoFile == null) {
            state = LoadState.success;
            videoFile = fileResponse.file;
            onComplete();
          }
        }
      });
    }
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;

  StoryVideo(this.videoLoader, {this.storyController, Key? key})
      : super(key: key ?? UniqueKey());

  static StoryVideo url(
      {String? url,
      String? file,
      StoryController? controller,
      Map<String, String>? requestHeaders,
      Key? key}) {
    return StoryVideo(
      VideoLoader(url: url, file: file, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController!.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        playerController =
            VideoPlayerController.file(widget.videoLoader.videoFile!);

        playerController!.initialize().then((v) {
          setState(() {});
          widget.storyController!.play();
        });

        if (widget.storyController != null) {
          _streamSubscription =
              widget.storyController!.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              playerController!.pause();
            } else {
              playerController!.play();
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success &&
        playerController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: playerController!.value.aspectRatio,
          child: VideoPlayer(playerController!),
        ),
      );
    }

    return widget.videoLoader.state == LoadState.loading
        ? Center(
            child: Container(
              width: 70,
              height: 70,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          )
        : Center(
            child: Text(
            "Media failed to load.",
            style: TextStyle(
              color: Colors.white,
            ),
          ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
