import numpy as np
import cv2
import os
from ultralytics import YOLO
from deep_sort_realtime.deepsort_tracker import DeepSort

# 載入 YOLOv11 模型
model = YOLO('C:/Users/iceca/Desktop/dd/runs/detect/train27/weights/best.pt')

# 讀取影片
cap = cv2.VideoCapture("C:/Users/iceca/Desktop/ViViT-Implementation-main/meowing.mp4")
fps = cap.get(cv2.CAP_PROP_FPS)
size = (int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
videoWriter = cv2.VideoWriter("C:/Users/iceca/Desktop/dd/testmwoqin.mp4", fourcc, 24, size)

# 初始化 DeepSORT 追蹤器
tracker = DeepSort(max_age=30, n_init=10, embedder="clip_ViT-B/16")

# 儲存影像的資料夾
output_dir = "C:/Users/iceca/Desktop/dd/cat_clips"
os.makedirs(output_dir, exist_ok=True)
track_clips = {}  # 用來儲存不同追蹤 ID 的影格

# 讀取影片逐幀處理
frame_id = 0  
while cap.isOpened():
    success, frame = cap.read()
    if not success:
        break

    frame_id += 1  
    
    # 執行 YOLO 物件偵測，設定信心值 conf=0.6
    results = model.predict(frame, conf=0.6)
    outputs = results[0].boxes.data.cpu().numpy()

    detections = []
    if outputs is not None:
        for output in outputs:
            x1, y1, x2, y2 = list(map(int, output[:4]))
            class_id = int(output[5])
            
            if class_id == 15:  # 只保留 "cat"
                detections.append(([x1, y1, x2 - x1, y2 - y1], output[4], 'cat'))

        # 更新追蹤器
        tracks = tracker.update_tracks(detections, frame=frame)
        
        for track in tracks:
            if not track.is_confirmed():
                continue
            track_id = track.track_id
            bbox = track.to_ltrb()
            x1, y1, x2, y2 = map(int, bbox)
            
            # 裁剪影像
            cropped = frame[y1:y2, x1:x2]
            if cropped.size == 0:
                continue

            # 重新調整尺寸 (符合 ViViT 模型輸入)
            cropped_resized = cv2.resize(cropped, (224, 224))
            
            # 儲存影格到對應的追蹤 ID 資料夾
            track_folder = os.path.join(output_dir, f"track_{track_id}")
            os.makedirs(track_folder, exist_ok=True)
            cv2.imwrite(os.path.join(track_folder, f"frame_{frame_id}.jpg"), cropped_resized)
            
            # 儲存追蹤 ID 的影格
            if track_id not in track_clips:
                track_clips[track_id] = []
            track_clips[track_id].append(cropped_resized)
            
            # 畫出追蹤框
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, f'Cat #{track_id}', (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)


   
    videoWriter.write(frame)

   

# 釋放資源
cap.release()
videoWriter.release()


print("處理完成，影像已儲存至:", output_dir)

# 輸出追蹤影片
for track_id, frames in track_clips.items():
    # 設定影片輸出檔案路徑
    track_video_path = os.path.join(output_dir, f"track_{track_id}.mp4")
    # (此處所有的影格都已重新調整至 224x224)
    height, width, _ = frames[0].shape
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(track_video_path, fourcc, 24, (width, height))
    
    for frame in frames:
        out.write(frame)
    out.release()
    print(f"追蹤影片儲存完成：{track_video_path}")
