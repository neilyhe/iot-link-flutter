import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

final class FlvVec extends ffi.Struct {
  external ffi.Pointer<ffi.Void> ptr;
  @ffi.Int32()
  external int len;
}

final class FlvMetadata extends ffi.Struct {
  @ffi.Int32()
  external int audiocodecid;
  @ffi.Double()
  external double audiodatarate;
  @ffi.Int32()
  external int audiosamplerate;
  @ffi.Int32()
  external int audiosamplesize;
  @ffi.Int32()
  external int stereo;
  
  @ffi.Int32()
  external int videocodecid;
  @ffi.Double()
  external double videodatarate;
  @ffi.Double()
  external double framerate;
  @ffi.Double()
  external double duration;
  @ffi.Int32()
  external int interval;
  @ffi.Int32()
  external int width;
  @ffi.Int32()
  external int height;
}

/// FLV Muxer回调函数类型
typedef FlvMuxerHandlerNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void> param,
  ffi.Int32 type,
  ffi.Pointer<ffi.Void> data,
  ffi.Size bytes,
  ffi.Uint32 timestamp,
);

typedef FlvMuxerHandlerDart = int Function(
  ffi.Pointer<ffi.Void> param,
  int type,
  ffi.Pointer<ffi.Void> data,
  int bytes,
  int timestamp,
);

/// FLV Writer回调函数类型
typedef FlvWriterOnwriteNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void> param,
  ffi.Pointer<FlvVec> vec,
  ffi.Int32 n,
);

typedef FlvWriterOnwriteDart = int Function(
  ffi.Pointer<ffi.Void> param,
  ffi.Pointer<FlvVec> vec,
  int n,
);

class FlvFfiBindings {
  late final ffi.DynamicLibrary _dylib;
  
  FlvFfiBindings() {
    if (Platform.isAndroid) {
      _dylib = ffi.DynamicLibrary.open('libflv-core.so');
    } else if (Platform.isIOS) {
      _dylib = ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // ========== FLV Writer 函数 ==========
  
  late final _flv_writer_create = _dylib.lookupFunction<
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>),
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>)
  >('flv_writer_create');
  
  ffi.Pointer<ffi.Void> flvWriterCreate(String file) {
    final filePtr = file.toNativeUtf8();
    final result = _flv_writer_create(filePtr);
    malloc.free(filePtr);
    return result;
  }

  late final _flv_writer_create2 = _dylib.lookupFunction<
    ffi.Pointer<ffi.Void> Function(
      ffi.Int32,
      ffi.Int32,
      ffi.Pointer<ffi.NativeFunction<FlvWriterOnwriteNative>>,
      ffi.Pointer<ffi.Void>,
    ),
    ffi.Pointer<ffi.Void> Function(
      int,
      int,
      ffi.Pointer<ffi.NativeFunction<FlvWriterOnwriteNative>>,
      ffi.Pointer<ffi.Void>,
    )
  >('flv_writer_create2');
  
  ffi.Pointer<ffi.Void> flvWriterCreate2(
    int audio,
    int video,
    ffi.Pointer<ffi.NativeFunction<FlvWriterOnwriteNative>> onwrite,
    ffi.Pointer<ffi.Void> param,
  ) {
    return _flv_writer_create2(audio, video, onwrite, param);
  }

  late final _flv_writer_destroy = _dylib.lookupFunction<
    ffi.Void Function(ffi.Pointer<ffi.Void>),
    void Function(ffi.Pointer<ffi.Void>)
  >('flv_writer_destroy');
  
  void flvWriterDestroy(ffi.Pointer<ffi.Void> flv) {
    _flv_writer_destroy(flv);
  }

  late final _flv_writer_input = _dylib.lookupFunction<
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void>,
      ffi.Int32,
      ffi.Pointer<ffi.Void>,
      ffi.Size,
      ffi.Uint32,
    ),
    int Function(
      ffi.Pointer<ffi.Void>,
      int,
      ffi.Pointer<ffi.Void>,
      int,
      int,
    )
  >('flv_writer_input');
  
  int flvWriterInput(
    ffi.Pointer<ffi.Void> flv,
    int type,
    ffi.Pointer<ffi.Void> data,
    int bytes,
    int timestamp,
  ) {
    return _flv_writer_input(flv, type, data, bytes, timestamp);
  }

  // ========== FLV Muxer 函数 ==========
  
  late final _flv_muxer_create = _dylib.lookupFunction<
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.NativeFunction<FlvMuxerHandlerNative>>,
      ffi.Pointer<ffi.Void>,
    ),
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.NativeFunction<FlvMuxerHandlerNative>>,
      ffi.Pointer<ffi.Void>,
    )
  >('flv_muxer_create');
  
  ffi.Pointer<ffi.Void> flvMuxerCreate(
    ffi.Pointer<ffi.NativeFunction<FlvMuxerHandlerNative>> handler,
    ffi.Pointer<ffi.Void> param,
  ) {
    return _flv_muxer_create(handler, param);
  }

  late final _flv_muxer_destroy = _dylib.lookupFunction<
    ffi.Void Function(ffi.Pointer<ffi.Void>),
    void Function(ffi.Pointer<ffi.Void>)
  >('flv_muxer_destroy');
  
  void flvMuxerDestroy(ffi.Pointer<ffi.Void> muxer) {
    _flv_muxer_destroy(muxer);
  }

  late final _flv_muxer_aac = _dylib.lookupFunction<
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Size,
      ffi.Uint32,
      ffi.Uint32,
    ),
    int Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      int,
      int,
      int,
    )
  >('flv_muxer_aac');
  
  int flvMuxerAac(
    ffi.Pointer<ffi.Void> muxer,
    ffi.Pointer<ffi.Void> data,
    int bytes,
    int pts,
    int dts,
  ) {
    return _flv_muxer_aac(muxer, data, bytes, pts, dts);
  }

  late final _flv_muxer_avc = _dylib.lookupFunction<
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      ffi.Size,
      ffi.Uint32,
      ffi.Uint32,
    ),
    int Function(
      ffi.Pointer<ffi.Void>,
      ffi.Pointer<ffi.Void>,
      int,
      int,
      int,
    )
  >('flv_muxer_avc');
  
  int flvMuxerAvc(
    ffi.Pointer<ffi.Void> muxer,
    ffi.Pointer<ffi.Void> data,
    int bytes,
    int pts,
    int dts,
  ) {
    return _flv_muxer_avc(muxer, data, bytes, pts, dts);
  }

  late final _flv_muxer_reset = _dylib.lookupFunction<
    ffi.Int32 Function(ffi.Pointer<ffi.Void>),
    int Function(ffi.Pointer<ffi.Void>)
  >('flv_muxer_reset');
  
  int flvMuxerReset(ffi.Pointer<ffi.Void> muxer) {
    return _flv_muxer_reset(muxer);
  }

  late final _flv_muxer_metadata = _dylib.lookupFunction<
    ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<FlvMetadata>),
    int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<FlvMetadata>)
  >('flv_muxer_metadata');
  
  int flvMuxerMetadata(
    ffi.Pointer<ffi.Void> muxer,
    ffi.Pointer<FlvMetadata> metadata,
  ) {
    return _flv_muxer_metadata(muxer, metadata);
  }
}