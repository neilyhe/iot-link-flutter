#ifndef XP2P_DART_BRIDGE_H
#define XP2P_DART_BRIDGE_H

#include <stdint.h>
#include <stddef.h>
#include "AppWrapper.h"

#ifdef __cplusplus
extern "C" {
#endif

// Dart API DL 初始化 (Android 必需)
int64_t xp2p_init_dart_api(void* init_data);

// Dart Port 管理
void xp2p_set_dart_port(int64_t request_port, int64_t response_port);
void xp2p_clear_dart_port();

// 回调桥接函数
void xp2p_av_recv_bridge(const char *id, uint8_t *data, size_t len);
const char* xp2p_msg_bridge(const char *id, XP2PType type, const char *msg);
char* xp2p_device_data_bridge(const char *id, uint8_t *data, size_t len);

// 处理 Dart 端的响应
void xp2p_handle_device_data_response(const char* id, const char* response);

#ifdef __cplusplus
}
#endif

#endif
