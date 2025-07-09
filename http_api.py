from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
import threading
from datetime import datetime

app = Flask(__name__)
CORS(app)  # 允許跨域請求

# 用於儲存分類次數的檔案
STATS_FILE = "user_stats.json"

# 加載或初始化用戶統計資料
def load_user_stats():
    if os.path.exists(STATS_FILE):
        try:
            with open(STATS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {}
    return {}

# 保存用戶統計資料
def save_user_stats(stats):
    try:
        with open(STATS_FILE, 'w', encoding='utf-8') as f:
            json.dump(stats, f, ensure_ascii=False, indent=2)
    except IOError as e:
        print(f"Error saving stats: {e}")

# 初始化用戶統計資料
user_stats = load_user_stats()
stats_lock = threading.Lock()

# 預設分類類別
CATEGORIES = ["eating", "licking", "relex", "toilet"]

def ensure_user_stats(user_id):
    #確保用戶統計資料結構存在
    if user_id not in user_stats:
        user_stats[user_id] = {
            "total_count": 0,
            "categories": {category: 0 for category in CATEGORIES},
            "last_update": datetime.now().isoformat()
        }


@app.route('/api/classification', methods=['POST'])
def add_classification():
    #新增分類記錄 API
    try:
        data = request.get_json()
        
        # 檢查必要參數
        if not data or 'user_id' not in data or 'category' not in data:
            return jsonify({
                "error": "Missing required parameters: user_id and category"
            }), 400
        
        user_id = str(data['user_id'])
        category = data['category']
        
        # 檢查類別是否有效
        if category not in CATEGORIES:
            return jsonify({
                "error": f"Invalid category. Must be one of: {CATEGORIES}"
            }), 400
        
        # 更新統計資料
        with stats_lock:
            ensure_user_stats(user_id)
            user_stats[user_id]["categories"][category] += 1
            user_stats[user_id]["total_count"] += 1
            user_stats[user_id]["last_update"] = datetime.now().isoformat()
            save_user_stats(user_stats)
        
        return jsonify({
            "message": "Classification added successfully",
            "user_id": user_id,
            "category": category,
            "new_count": user_stats[user_id]["categories"][category],
            "total_count": user_stats[user_id]["total_count"]
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/stats/<user_id>', methods=['GET'])
def get_user_stats(user_id):
    #查詢特定用戶的統計資料 API
    try:
        user_id = str(user_id)
        
        with stats_lock:
            ensure_user_stats(user_id)
            stats = user_stats[user_id].copy()
        
        return jsonify({
            "user_id": user_id,
            "stats": stats
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/stats', methods=['GET'])
def get_all_stats():
    #查詢所有用戶的統計資料 API
    try:
        with stats_lock:
            stats = user_stats.copy()
        
        return jsonify({
            "all_users": stats,
            "total_users": len(stats)
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/stats/<user_id>', methods=['DELETE'])
def reset_user_stats(user_id):
    #重置特定用戶的統計資料 API
    try:
        user_id = str(user_id)
        
        with stats_lock:
            if user_id in user_stats:
                user_stats[user_id] = {
                    "total_count": 0,
                    "categories": {category: 0 for category in CATEGORIES},
                    "last_update": datetime.now().isoformat()
                }
                save_user_stats(user_stats)
                message = f"Stats reset for user {user_id}"
            else:
                message = f"User {user_id} not found, but initialized with zero stats"
                ensure_user_stats(user_id)
                save_user_stats(user_stats)
        
        return jsonify({
            "message": message,
            "user_id": user_id,
            "stats": user_stats[user_id]
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/categories', methods=['GET'])
def get_categories():
    #取得所有可用的分類類別 API
    return jsonify({
        "categories": CATEGORIES,
        "total_categories": len(CATEGORIES)
    })

if __name__ == '__main__':

    print("\nServer running on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
