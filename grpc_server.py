import grpc
from concurrent import futures
import cv2
import numpy as np
import torch
import io
import threading
import os
from ultralytics import YOLO
from deep_sort_realtime.deepsort_tracker import DeepSort
from model import ViViT_Factorized
import image_stream_pb2
import image_stream_pb2_grpc
import time

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

#狀態追蹤
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
    track_clips[track_id] = track_clips[track_id][-48:]
    return class_names[top_class.item()], top_prob.item()

# gRPC 服務
class ImageStreamService(image_stream_pb2_grpc.ImageStreamServiceServicer):
    def StreamImages(self, request_iterator, context):
        for req in request_iterator:
            try:
                start_time = time.time()  #  Start timer
                frame_data = np.frombuffer(req.image, dtype=np.uint8)
                frame = cv2.imdecode(frame_data, cv2.IMREAD_COLOR)

                results = yolo_model.predict(source=frame, conf=0.6,half=True,verbose=False)
                outputs = results[0].boxes.data.cpu().numpy()

                detections = []
                for output in outputs:
                    x1, y1, x2, y2 = list(map(int, output[:4]))
                    class_id = int(output[5])
                    if class_id == 15:
                        detections.append(([x1, y1, x2 - x1, y2 - y1], output[4], 'cat'))

                tracks = tracker.update_tracks(detections, frame=frame)

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

                _, encoded_img = cv2.imencode('.jpg', frame)
                end_time = time.time()  #  End timer
                print(f" Frame processing time: {(end_time - start_time)*1000:.2f} ms")
                yield image_stream_pb2.ImageResponse(image=encoded_img.tobytes())

            except Exception as e:
                print(f" gRPC Error: {e}")
                continue

# 啟動 Server 
def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    image_stream_pb2_grpc.add_ImageStreamServiceServicer_to_server(ImageStreamService(), server)
    server.add_insecure_port('[::]:50051')
    print("gRPC Server listening on port 50051")
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
