import grpc
from concurrent import futures
import cv2
import numpy as np
import torch
import io
import threading
import queue
import os
import time
11111
from ultralytics import YOLO
from deep_sort_realtime.deepsort_tracker import DeepSort
from model import ViViT_Factorized
import image_stream_pb2
import image_stream_pb2_grpc

# 設定 
NUM_FRAMES = 72
IMG_SIZE = 224
EMBED_DIM = 96
MLP_DIM = 96 * 3
NUM_HEADS = 4
NUM_LAYERS_SPATIAL = 3
NUM_LAYERS_TEMPORAL = 2
PATCH_SIZE = 16
TUBELET_SIZE = 2
DATASET_PATH = "C:/Users/iceca/Desktop/ViViT-Implementation-main/test"
MODEL_PATH = "C:/Users/iceca/Desktop/ViViT-Implementation-main/last_model.pth"

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# 模型載入
yolo_model = YOLO("C:/Users/iceca/Desktop/dd/runs/detect/train27/weights/best.pt")
tracker = DeepSort(max_age=30, n_init=5, embedder="clip_ViT-B/16")
vivit_model = ViViT_Factorized(
    in_channels=3, embed_dim=EMBED_DIM, patch_size=PATCH_SIZE, tubelet_size=TUBELET_SIZE,
    num_heads=NUM_HEADS, mlp_dim=MLP_DIM, num_layers_spatial=NUM_LAYERS_SPATIAL, num_layers_temporal=NUM_LAYERS_TEMPORAL,
    num_classes=len(os.listdir(DATASET_PATH)), num_frames=NUM_FRAMES, img_size=IMG_SIZE, droplayer_p=0.1
).to(device)
vivit_model.load_state_dict(torch.load(MODEL_PATH))
vivit_model.eval()
class_names = sorted(os.listdir(DATASET_PATH))

# 狀態追蹤
track_clips = {}
track_labels = {}

def preprocess_video(frames, frame_size=(224, 224)):
    frames = [cv2.resize(f, frame_size)[:, :, ::-1] for f in frames]
    frames = np.array(frames, dtype=np.float32) / 255.0
    frames_tensor = torch.tensor(frames).permute(3, 0, 1, 2)
    return frames_tensor.unsqueeze(0).to(device)

def predict_action(track_id):
    if len(track_clips.get(track_id, [])) < NUM_FRAMES:
        return None, None
    frames_tensor = preprocess_video(track_clips[track_id])
    with torch.no_grad():
        outputs = vivit_model(frames_tensor)
        probs = torch.nn.functional.softmax(outputs, dim=1)
        top_prob, top_class = torch.max(probs, dim=1)
    # 保留最新的 48 幀
    track_clips[track_id] = track_clips[track_id][-48:]
    return class_names[top_class.item()], top_prob.item()

# 建立多階段處理的佇列，採用 tuple: (frame, result_q)
yolo_queue = queue.Queue()
tracker_queue = queue.Queue()
vivit_queue = queue.Queue()

# YOLO 偵測執行緒
def yolo_worker():
    while True:
        item = yolo_queue.get()
        if item is None:
            break
        frame, result_q = item
        try:
            results = yolo_model.predict(source=frame, conf=0.6, half=True, verbose=False)
            outputs = results[0].boxes.data.cpu().numpy()
            tracker_queue.put((frame, outputs, result_q))
        except Exception as e:
            print(f"YOLO Error: {e}")
            result_q.put(frame)
        finally:
            yolo_queue.task_done()

# DeepSort 追蹤執行緒
def tracker_worker():
    while True:
        item = tracker_queue.get()
        if item is None:
            break
        frame, outputs, result_q = item
        try:
            detections = []
            for output in outputs:
                x1, y1, x2, y2 = list(map(int, output[:4]))
                class_id = int(output[5])
                if class_id == 15:
                    detections.append(([x1, y1, x2 - x1, y2 - y1], output[4], 'cat'))
            tracks = tracker.update_tracks(detections, frame=frame)
            vivit_queue.put((frame, tracks, result_q))
        except Exception as e:
            print(f"Tracker Error: {e}")
            result_q.put(frame)
        finally:
            tracker_queue.task_done()

# ViViT 動作預測執行緒及影像標注
def vivit_worker():
    while True:
        item = vivit_queue.get()
        if item is None:
            break
        frame, tracks, result_q = item
        try:
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
            # 將最終處理後的 frame 傳至 result_q
            result_q.put(frame)
        except Exception as e:
            print(f"ViViT Worker Error: {e}")
            result_q.put(frame)
        finally:
            vivit_queue.task_done()

# 啟動工作執行緒
yolo_thread = threading.Thread(target=yolo_worker, daemon=True)
tracker_thread = threading.Thread(target=tracker_worker, daemon=True)
vivit_thread = threading.Thread(target=vivit_worker, daemon=True)
yolo_thread.start()
tracker_thread.start()
vivit_thread.start()

# gRPC 服務
class ImageStreamService(image_stream_pb2_grpc.ImageStreamServiceServicer):
    def StreamImages(self, request_iterator, context):
        for req in request_iterator:
            try:
                start_time = time.time()  # Start timer
                frame_data = np.frombuffer(req.image, dtype=np.uint8)
                frame = cv2.imdecode(frame_data, cv2.IMREAD_COLOR)
                # 為此 frame 建立專屬的結果佇列
                result_q = queue.Queue()
                # 將 frame 放入 YOLO 佇列，並傳遞 result_q
                yolo_queue.put((frame, result_q))
                # 等待處理完成，設定 timeout 避免無限等待（例如 5 秒）
                processed_frame = result_q.get(timeout=5)
                _, encoded_img = cv2.imencode('.jpg', processed_frame)
                end_time = time.time()  # End timer
                print(f"Frame processing time: {(end_time - start_time)*1000:.2f} ms")
                yield image_stream_pb2.ImageResponse(image=encoded_img.tobytes())
            except Exception as e:
                print(f"gRPC Error: {e}")
                continue

# 啟動 gRPC Server
def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    image_stream_pb2_grpc.add_ImageStreamServiceServicer_to_server(ImageStreamService(), server)
    server.add_insecure_port('[::]:50051')
    print("gRPC Server listening on port 50051")
    server.start()
    server.wait_for_termination()

# 結束時停止所有工作執行緒
def stop_workers():
    yolo_queue.put(None)
    tracker_queue.put(None)
    vivit_queue.put(None)
    yolo_thread.join()
    tracker_thread.join()
    vivit_thread.join()

if __name__ == '__main__':
    try:
        serve()
    except KeyboardInterrupt:
        stop_workers()
