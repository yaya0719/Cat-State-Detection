import numpy as np
import cv2
from ultralytics import YOLO
from deep_sort_realtime.deepsort_tracker import DeepSort

# 載入 YOLOv11 模型
model = YOLO('yolo11n.pt')

# 讀取影片
cap = cv2.VideoCapture("C:/Users/iceca/Desktop/dd/cat.mp4")
fps = cap.get(cv2.CAP_PROP_FPS)
size = (int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
videoWriter = cv2.VideoWriter("C:/Users/iceca/Desktop/dd/catrack.mp4", fourcc, fps, size)

# 初始化 DeepSORT 追蹤器
tracker = DeepSort(max_age=5)

# 定義標註函式
def box_label(image, box, label='', color=(0, 255, 0), txt_color=(255, 255, 255)):
    p1, p2 = (int(box[0]), int(box[1])), (int(box[2]), int(box[3]))
    cv2.rectangle(image, p1, p2, color, thickness=2, lineType=cv2.LINE_AA)
    if label:
        w, h = cv2.getTextSize(label, 0, fontScale=1, thickness=2)[0]
        outside = p1[1] - h >= 3
        p2 = p1[0] + w, p1[1] - h - 3 if outside else p1[1] + h + 3
        cv2.rectangle(image, p1, p2, color, -1, cv2.LINE_AA)
        cv2.putText(image, label, (p1[0], p1[1] - 2 if outside else p1[1] + h + 2), 
                    0, 1, txt_color, thickness=2, lineType=cv2.LINE_AA)

# 讀取影片逐幀處理
while cap.isOpened():
    success, frame = cap.read()
    if not success:
        break

    # 執行 YOLO 物件偵測，設定信心值 conf=0.4
    results = model(frame, conf=0.4)
    outputs = results[0].boxes.data.cpu().numpy()

    # 儲存貓的偵測結果
    detections = []
    
    if outputs is not None:
        for output in outputs:
            x1, y1, x2, y2 = list(map(int, output[:4]))  # 取得邊界框
            class_id = int(output[5])  # 取得類別 ID
            
            # 只保留 "cat" (類別 ID = 15)
            if class_id == 15:
                detections.append(([x1, y1, int(x2-x1), int(y2-y1)], output[4], 'cat'))

        # 更新追蹤器
        tracks = tracker.update_tracks(detections, frame=frame)

        # 畫出追蹤框
        for track in tracks:
            if not track.is_confirmed():
                continue
            track_id = track.track_id
            bbox = track.to_ltrb()
            box_label(frame, bbox, f'Cat #{track_id}', (0, 255, 0))  # 綠色框標註

    # 顯示畫面並存檔
    cv2.imshow("Cat Tracking", frame)
    videoWriter.write(frame)

    if cv2.waitKey(1) & 0xFF == ord("q"):  # 按 Q 退出
        break

# 釋放資源
cap.release()
videoWriter.release()
cv2.destroyAllWindows()
