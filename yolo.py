from ultralytics import YOLO

def train_yolo():
    # 加載 YOLO 模型
    model = YOLO("yolo11n.pt")

    # 訓練模型
    train_results = model.train(
        data="C:/Users/iceca/Desktop/dd/test.yaml",  # 資料集 YAML 檔案
        epochs=10,  # 訓練回合數
        imgsz=640,  # 訓練影像大小
        device="cuda",  # 使用 GPU
    )

    # 驗證模型表現
    metrics = model.val()


    # 匯出 ONNX 模型
    path = model.export(format="onnx")
    print(f"Model exported to {path}")

if __name__ == "__main__":
    train_yolo()
