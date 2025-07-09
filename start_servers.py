
#統一啟動
import threading
import time
import subprocess
import sys
import os

def start_grpc_server():
    print("start gRPC Server...")
    try:
        subprocess.run([sys.executable, "grpc_server.py"], check=True)
    except Exception as e:
        print(f"gRPC Server error: {e}")

def start_http_api():
    print("Start HTTP API...")
    try:
        subprocess.run([sys.executable, "http_api.py"], check=True)
    except Exception as e:
        print(f"HTTP API error: {e}")

def main():
    print("Starting both gRPC Server (port 50051) and HTTP API (port 5000)")
    
    # 建立thread來同時運行http，grpc服務及大罷免
    grpc_thread = threading.Thread(target=start_grpc_server, daemon=True)
    http_thread = threading.Thread(target=start_http_api, daemon=True)
    
    # 啟動服務
    grpc_thread.start()
    time.sleep(2)  
    http_thread.start()
    
    
    try:
        # 主執行緒保持運行
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n Stopp servers")
        sys.exit(0)

if __name__ == "__main__":
    main()
