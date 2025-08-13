// This is a generated file - do not edit.
//
// Generated from image_stream.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'image_stream.pb.dart' as $0;

export 'image_stream.pb.dart';

@$pb.GrpcServiceName('ImageStreamService')
class ImageStreamServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ImageStreamServiceClient(super.channel, {super.options, super.interceptors});

  /// 原有的雙向串流（保持相容性）
  $grpc.ResponseStream<$0.ImageResponse> streamImages($async.Stream<$0.ImageRequest> request, {$grpc.CallOptions? options,}) {
    return $createStreamingCall(_$streamImages, request, options: options);
  }

  /// 新增：相機端上傳影像串流（類似 POST）
  $grpc.ResponseFuture<$0.UploadResponse> uploadStream($async.Stream<$0.ImageRequest> request, {$grpc.CallOptions? options,}) {
    return $createStreamingCall(_$uploadStream, request, options: options).single;
  }

  /// 新增：觀看端接收處理後影像串流（類似 GET）
  $grpc.ResponseStream<$0.ImageResponse> watchStream($0.WatchRequest request, {$grpc.CallOptions? options,}) {
    return $createStreamingCall(_$watchStream, $async.Stream.fromIterable([request]), options: options);
  }

    // method descriptors

  static final _$streamImages = $grpc.ClientMethod<$0.ImageRequest, $0.ImageResponse>(
      '/ImageStreamService/StreamImages',
      ($0.ImageRequest value) => value.writeToBuffer(),
      $0.ImageResponse.fromBuffer);
  static final _$uploadStream = $grpc.ClientMethod<$0.ImageRequest, $0.UploadResponse>(
      '/ImageStreamService/UploadStream',
      ($0.ImageRequest value) => value.writeToBuffer(),
      $0.UploadResponse.fromBuffer);
  static final _$watchStream = $grpc.ClientMethod<$0.WatchRequest, $0.ImageResponse>(
      '/ImageStreamService/WatchStream',
      ($0.WatchRequest value) => value.writeToBuffer(),
      $0.ImageResponse.fromBuffer);
}

@$pb.GrpcServiceName('ImageStreamService')
abstract class ImageStreamServiceBase extends $grpc.Service {
  $core.String get $name => 'ImageStreamService';

  ImageStreamServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ImageRequest, $0.ImageResponse>(
        'StreamImages',
        streamImages,
        true,
        true,
        ($core.List<$core.int> value) => $0.ImageRequest.fromBuffer(value),
        ($0.ImageResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ImageRequest, $0.UploadResponse>(
        'UploadStream',
        uploadStream,
        true,
        false,
        ($core.List<$core.int> value) => $0.ImageRequest.fromBuffer(value),
        ($0.UploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.WatchRequest, $0.ImageResponse>(
        'WatchStream',
        watchStream_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.WatchRequest.fromBuffer(value),
        ($0.ImageResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ImageResponse> streamImages($grpc.ServiceCall call, $async.Stream<$0.ImageRequest> request);

  $async.Future<$0.UploadResponse> uploadStream($grpc.ServiceCall call, $async.Stream<$0.ImageRequest> request);

  $async.Stream<$0.ImageResponse> watchStream_Pre($grpc.ServiceCall $call, $async.Future<$0.WatchRequest> $request) async* {
    yield* watchStream($call, await $request);
  }

  $async.Stream<$0.ImageResponse> watchStream($grpc.ServiceCall call, $0.WatchRequest request);

}
