import queue
import threading

# 建立佇列
yolo_queue = queue.Queue()
tracker_queue = queue.Queue()
output_queue = queue.Queue()

# YOLO 偵測執行緒
def yolo_worker():
    while True:
        frame = yolo_queue.get()
        if frame is None:  # 停止訊號
            break
        results = yolo_model.predict(source=frame, conf=0.6, half=True, verbose=False)
        outputs = results[0].boxes.data.cpu().numpy()
        tracker_queue.put((frame, outputs))
        yolo_queue.task_done()

# DeepSort 追蹤執行緒
def tracker_worker():
    while True:
        data = tracker_queue.get()
        if data is None:  # 停止訊號
            break
        frame, outputs = data
        detections = []
        for output in outputs:
            x1, y1, x2, y2 = list(map(int, output[:4]))
            class_id = int(output[5])
            if class_id == 15:
                detections.append(([x1, y1, x2 - x1, y2 - y1], output[4], 'cat'))
        tracks = tracker.update_tracks(detections, frame=frame)
        output_queue.put((frame, tracks))
        tracker_queue.task_done()

# ViViT 動作預測執行緒
def vivit_worker():
    while True:
        data = output_queue.get()
        if data is None:  # 停止訊號
            break
        frame, tracks = data
        for track in tracks:
            if not track.is_confirmed():
                continue
            track_id = track.track_id
            x1, y1, x2, y2 = map(int, track.to_ltrb())
            cropped = frame[y1:y2, x1:x2]
            if cropped.size == 0:
                continue
            track_clips.setdefault(track_id, []).append(cropped)

            if len(track_clips[track_id]) == NUM_FRAMES:
                label, prob = predict_action(track_id)
                if label:
                    track_labels[track_id] = (label, prob)

            label_text = f"Cat #{track_id}"
            if track_id in track_labels:
                label_text += f" | {track_labels[track_id][0]} ({track_labels[track_id][1]:.2f})"

            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, label_text, (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        output_queue.task_done()

# 啟動執行緒
yolo_thread = threading.Thread(target=yolo_worker, daemon=True)
tracker_thread = threading.Thread(target=tracker_worker, daemon=True)
vivit_thread = threading.Thread(target=vivit_worker, daemon=True)

yolo_thread.start()
tracker_thread.start()
vivit_thread.start()

# 修改 gRPC 服務
class ImageStreamService(image_stream_pb2_grpc.ImageStreamServiceServicer):
    def StreamImages(self, request_iterator, context):
        for req in request_iterator:
            try:
                frame_data = np.frombuffer(req.image, dtype=np.uint8)
                frame = cv2.imdecode(frame_data, cv2.IMREAD_COLOR)
                yolo_queue.put(frame)  # 將影像放入 YOLO 佇列

                # 等待處理完成
                output_queue.join()

                # 取出處理後的影像
                _, encoded_img = cv2.imencode('.jpg', frame)
                yield image_stream_pb2.ImageResponse(image=encoded_img.tobytes())

            except Exception as e:
                print(f" gRPC Error: {e}")
                continue

# 停止執行緒
def stop_workers():
    yolo_queue.put(None)
    tracker_queue.put(None)
    output_queue.put(None)
    yolo_thread.join()
    tracker_thread.join()
    vivit_thread.join()

if __name__ == '__main__':
    try:
        serve()
    except KeyboardInterrupt:
        stop_workers()
