#include "dart_bridge.h"

// ==================== 所有平台统一使用 Dart API DL ====================
// 使用 dart_api_dl.h (Dart FFI 动态链接 API)
// 这是跨平台的标准做法,适用于 Android/iOS/Windows/Linux/macOS
#include <dart_api_dl.h>

#include <string.h>
#include <stdlib.h>
#include <map>
#include <mutex>
#include <string>
#include <memory>
#include <condition_variable>
#include <chrono>

// 平台相关的日志
#ifdef __ANDROID__
    #include <android/log.h>
    #define TAG "XP2P_Bridge"
    #define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)
    #define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#elif defined(__APPLE__)
    #include <os/log.h>
    #define LOGD(fmt, ...) os_log_debug(OS_LOG_DEFAULT, fmt, ##__VA_ARGS__)
    #define LOGE(fmt, ...) os_log_error(OS_LOG_DEFAULT, fmt, ##__VA_ARGS__)
#else
    #include <stdio.h>
    #define LOGD(fmt, ...) printf("[DEBUG] " fmt "\n", ##__VA_ARGS__)
    #define LOGE(fmt, ...) fprintf(stderr, "[ERROR] " fmt "\n", ##__VA_ARGS__)
#endif

// ==================== 所有平台使用 Dart API DL ====================
// 标记 Dart API DL 是否已初始化
static bool g_dart_api_dl_initialized = false;

/**
 * 确保 Dart API DL 已初始化
 * 所有平台统一使用 Dart FFI 动态链接 API
 */
static bool ensure_dart_api_dl_initialized() {
    if (g_dart_api_dl_initialized) {
        return true;
    }
    
    return false;
}

// 所有平台统一使用 Dart_PostCObject_DL
#define Dart_PostCObject Dart_PostCObject_DL
#define Dart_Port Dart_Port_DL

// ==================== 全局变量 ====================

static Dart_Port g_dart_request_port = ILLEGAL_PORT;  // 用于发送请求到 Dart
static Dart_Port g_dart_response_port = ILLEGAL_PORT; // 预留给响应端口（当前未使用）
static std::mutex g_port_mutex;
static std::map<std::string, char*> g_string_cache;
static std::mutex g_cache_mutex;

// 请求-响应机制
struct PendingRequest {
    std::mutex mutex;
    std::condition_variable cv;
    std::string response;
    bool completed;
    
    PendingRequest() : completed(false) {}
};

static std::map<std::string, std::shared_ptr<PendingRequest>> g_pending_requests;
static std::mutex g_requests_mutex;
static uint64_t g_request_id_counter = 0;

// ==================== 辅助函数 ====================

static char* cache_string(const std::string& key, const std::string& value) {
    std::lock_guard<std::mutex> lock(g_cache_mutex);
    
    auto it = g_string_cache.find(key);
    if (it != g_string_cache.end()) {
        free(it->second);
    }
    
    char* cached = strdup(value.c_str());
    g_string_cache[key] = cached;
    return cached;
}

static bool post_to_dart(Dart_CObject* message) {
    std::lock_guard<std::mutex> lock(g_port_mutex);
    
    // 检查 port 是否有效
    if (g_dart_request_port == ILLEGAL_PORT) {
        LOGE("Dart request port not set! (ILLEGAL_PORT=%lld)", (long long)ILLEGAL_PORT);
        return false;
    }

    // 确保 Dart API DL 已初始化 (所有平台)
    if (!ensure_dart_api_dl_initialized()) {
        LOGE("Dart API DL not initialized!");
        return false;
    }
    
    // 如果是数组消息，打印详细信息
    if (message->type == Dart_CObject_kArray) {
        if (message->value.as_array.length > 0 &&
            message->value.as_array.values[0]->type == Dart_CObject_kString) {
        }
    }
    
    // 调用 Dart_PostCObject (在 Android 上是 Dart_PostCObject_DL)
    bool result = Dart_PostCObject(g_dart_request_port, message);
    
    if (!result) {
        LOGE("Dart_PostCObject returned FALSE");
        LOGE("Port %lld might be invalid or closed", (long long)g_dart_request_port);
    }
    
    return result;
}

/**
 * 发送设备数据请求并同步等待响应
 */
static std::string send_device_data_request_sync(const char* id, 
                                                  uint8_t* data, 
                                                  size_t len,
                                                  int timeout_ms = 5000) {
    // 生成唯一请求 ID
    std::string request_id;
    {
        std::lock_guard<std::mutex> lock(g_requests_mutex);
        request_id = std::string(id) + "_" + std::to_string(g_request_id_counter++);
    }

    // 创建待处理请求
    auto request = std::make_shared<PendingRequest>();
    {
        std::lock_guard<std::mutex> lock(g_requests_mutex);
        g_pending_requests[request_id] = request;
    }
    
    // 发送请求到 Dart
    // Dart 端接收格式: ['deviceDataRequest', 'request_id', 'id', Uint8List]
    Dart_CObject c_elements[4];
    Dart_CObject* element_ptrs[4];
    Dart_CObject c_message;
    
    c_elements[0].type = Dart_CObject_kString;
    c_elements[0].value.as_string = const_cast<char*>("deviceDataRequest");
    
    c_elements[1].type = Dart_CObject_kString;
    c_elements[1].value.as_string = const_cast<char*>(request_id.c_str());
    
    c_elements[2].type = Dart_CObject_kString;
    c_elements[2].value.as_string = const_cast<char*>(id);
    
    c_elements[3].type = Dart_CObject_kTypedData;
    c_elements[3].value.as_typed_data.type = Dart_TypedData_kUint8;
    c_elements[3].value.as_typed_data.length = len;
    c_elements[3].value.as_typed_data.values = data;
    
    for (int i = 0; i < 4; i++) {
        element_ptrs[i] = &c_elements[i];
    }
    
    c_message.type = Dart_CObject_kArray;
    c_message.value.as_array.length = 4;
    c_message.value.as_array.values = element_ptrs;
    
    if (!post_to_dart(&c_message)) {
        LOGE("Failed to send device data request");
        std::lock_guard<std::mutex> lock(g_requests_mutex);
        g_pending_requests.erase(request_id);
        return "";
    }
    
    // 等待响应（带超时）
    std::string response;
    {
        std::unique_lock<std::mutex> lock(request->mutex);
        if (request->cv.wait_for(lock, std::chrono::milliseconds(timeout_ms),
                                 [&request] { return request->completed; })) {
            // 成功收到响应
            response = request->response;
        } else {
            // 超时
            LOGE("Timeout waiting for response: request_id=%s", request_id.c_str());
        }
    }
    
    // 清理请求
    {
        std::lock_guard<std::mutex> lock(g_requests_mutex);
        g_pending_requests.erase(request_id);
    }
    
    return response;
}

/**
 * 创建 Array 类型的消息用于 avRecv 和 deviceData
 * 
 * Dart 端接收格式: ['avRecv', 'id', Uint8List]
 * 或: ['deviceData', 'id', Uint8List]
 */
static bool post_data_message(const char* type, const char* id, 
                               uint8_t* data, size_t len) {
    // 动态分配，线程安全
    Dart_CObject c_elements[3];
    Dart_CObject* element_ptrs[3];
    Dart_CObject c_message;
    
    c_elements[0].type = Dart_CObject_kString;
    c_elements[0].value.as_string = const_cast<char*>(type);
    
    c_elements[1].type = Dart_CObject_kString;
    c_elements[1].value.as_string = const_cast<char*>(id);
    
    c_elements[2].type = Dart_CObject_kTypedData;
    c_elements[2].value.as_typed_data.type = Dart_TypedData_kUint8;
    c_elements[2].value.as_typed_data.length = len;
    c_elements[2].value.as_typed_data.values = data;
    
    for (int i = 0; i < 3; i++) {
        element_ptrs[i] = &c_elements[i];
    }
    
    c_message.type = Dart_CObject_kArray;
    c_message.value.as_array.length = 3;
    c_message.value.as_array.values = element_ptrs;
    
    return post_to_dart(&c_message);
}

/**
 * 创建 Array 类型的消息用于 msg
 * 
 * Dart 端接收格式: ['msg', 'id', msgType(int), 'msgContent']
 */
static bool post_msg_message(const char* id, XP2PType msg_type, const char* msg) {
    static Dart_CObject c_elements[4];
    static Dart_CObject* element_ptrs[4];
    static Dart_CObject c_message;
    
    // 元素 0: 类型 "msg"
    c_elements[0].type = Dart_CObject_kString;
    c_elements[0].value.as_string = const_cast<char*>("msg");

    // 元素 1: ID
    c_elements[1].type = Dart_CObject_kString;
    c_elements[1].value.as_string = const_cast<char*>(id);
    
    // 元素 2: 消息类型 (int32)
    c_elements[2].type = Dart_CObject_kInt32;
    c_elements[2].value.as_int32 = msg_type;
    
    // 元素 3: 消息内容
    c_elements[3].type = Dart_CObject_kString;
    c_elements[3].value.as_string = const_cast<char*>(msg);
    
    // 组装指针数组
    for (int i = 0; i < 4; i++) {
        element_ptrs[i] = &c_elements[i];
    }
    
    // 构造 Array 消息
    c_message.type = Dart_CObject_kArray;
    c_message.value.as_array.length = 4;
    c_message.value.as_array.values = element_ptrs;
    
    return post_to_dart(&c_message);
}

// ==================== 公共 API ====================

extern "C" {

void xp2p_set_dart_port(int64_t request_port, int64_t response_port) {
    std::lock_guard<std::mutex> lock(g_port_mutex);
    
    LOGD("========== Setting Dart Ports ==========");
    LOGD("Request port:  %lld (0x%llx)", (long long)request_port, (unsigned long long)request_port);
    LOGD("Response port: %lld (0x%llx)", (long long)response_port, (unsigned long long)response_port);
    LOGD("ILLEGAL_PORT constant: %lld", (long long)ILLEGAL_PORT);
    
    if (request_port == 0 || request_port == ILLEGAL_PORT) {
        LOGE("WARNING: Request port looks invalid!");
    }
    
    g_dart_request_port = (Dart_Port)request_port;
    g_dart_response_port = (Dart_Port)response_port;
    
    // 检查 Dart API DL 是否已初始化 (所有平台)
    if (!g_dart_api_dl_initialized) {
        LOGE("WARNING: Dart API DL not initialized yet!");
        LOGE("You must call xp2p_init_dart_api() from Dart first");
    } else {
        // 测试发送一个简单消息
        LOGD("Sending test message...");
        Dart_CObject test_msg;
        test_msg.type = Dart_CObject_kString;
        test_msg.value.as_string = const_cast<char*>("__test__");
        
        if (Dart_PostCObject(g_dart_request_port, &test_msg)) {
            LOGD("Test message sent successfully!");
        } else {
            LOGE("Test message FAILED!");
            LOGE("Port might be invalid or Dart side not ready");
        }
    }
    
    LOGD("Registering XP2P callbacks...");
    setUserCallbackToXp2p(xp2p_av_recv_bridge, xp2p_msg_bridge, xp2p_device_data_bridge);
    LOGD("========== Dart Ports Setup Complete ==========");
}

/**
 * 初始化 Dart API DL (所有平台)
 * 必须在设置端口之前从 Dart 端调用
 * 
 * @param init_data 从 NativeApi.initializeApiDLData 获取的数据指针
 * @return 0 表示成功，非 0 表示失败
 */
int64_t xp2p_init_dart_api(void* init_data) {
    LOGD("========== Initializing Dart API DL ==========");
    LOGD("init_data pointer: %p", init_data);
    
    if (!init_data) {
        LOGE("init_data is NULL!");
        return -1;
    }
    
    intptr_t result = Dart_InitializeApiDL(init_data);
    if (result != 0) {
        LOGE("Dart_InitializeApiDL failed with code: %ld", (long)result);
        return result;
    }
    
    g_dart_api_dl_initialized = true;
    LOGD("Dart API DL initialized successfully");
    LOGD("Dart_PostCObject_DL is now available");
    
    LOGD("========== Dart API DL Init Complete ==========");
    return 0;
}

void xp2p_clear_dart_port() {
    std::lock_guard<std::mutex> lock(g_port_mutex);
    g_dart_request_port = ILLEGAL_PORT;
    g_dart_response_port = ILLEGAL_PORT;
    
    std::lock_guard<std::mutex> cache_lock(g_cache_mutex);
    for (auto& pair : g_string_cache) {
        free(pair.second);
    }
    g_string_cache.clear();
    
    LOGD("Dart callback port cleared");
}

void xp2p_av_recv_bridge(const char *id, uint8_t *data, size_t len) {
    post_data_message("avRecv", id, data, len);
}

const char* xp2p_msg_bridge(const char *id, XP2PType type, const char *msg) {
    // 特殊处理：需要立即返回的类型
    if (type == XP2PTypeSaveFileOn) {
        // 是否打开保存文件
        return "0";
    } else if (type == XP2PTypeSaveFileUrl) {
        // 文件存储路径
        return "";
    }
    
    // 异步发送消息到 Dart
    post_msg_message(id, type, msg);
    return "";
}

char* xp2p_device_data_bridge(const char *id, uint8_t *data, size_t len) {
    // 发送同步请求并等待响应
    std::string response = send_device_data_request_sync(id, data, len);
    
    if (response.empty()) {
        return nullptr;
    }
    
    // 分配内存并返回（调用者负责释放）
    return strdup(response.c_str());
}

void xp2p_handle_device_data_response(const char* request_id, const char* response) {
    if (!request_id || !response) {
        LOGE("Invalid parameters: request_id or response is null");
        return;
    }

    std::shared_ptr<PendingRequest> request;
    {
        std::lock_guard<std::mutex> lock(g_requests_mutex);
        auto it = g_pending_requests.find(request_id);
        if (it == g_pending_requests.end()) {
            LOGE("Request not found: %s", request_id);
            return;
        }
        request = it->second;
    }
    
    // 设置响应并通知等待线程
    {
        std::lock_guard<std::mutex> lock(request->mutex);
        request->response = response;
        request->completed = true;
    }
    request->cv.notify_one();
}

} // extern "C"
