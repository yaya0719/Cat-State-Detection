//
//  Generated code. Do not modify.
//  source: image_stream.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'image_stream.pb.dart' as $0;

export 'image_stream.pb.dart';

@$pb.GrpcServiceName('ImageStreamService')
class ImageStreamServiceClient extends $grpc.Client {
  static final _$streamImages = $grpc.ClientMethod<$0.ImageRequest, $0.ImageResponse>(
      '/ImageStreamService/StreamImages',
      ($0.ImageRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ImageResponse.fromBuffer(value));

  ImageStreamServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseStream<$0.ImageResponse> streamImages($async.Stream<$0.ImageRequest> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$streamImages, request, options: options);
  }
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
  }

  $async.Stream<$0.ImageResponse> streamImages($grpc.ServiceCall call, $async.Stream<$0.ImageRequest> request);
}
