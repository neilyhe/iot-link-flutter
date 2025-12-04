#ifndef SOUNDTOUCH_C_API_H
#define SOUNDTOUCH_C_API_H

#ifdef __cplusplus
extern "C" {
#endif

// 不透明指针类型，用于隐藏 C++ 实现
typedef void* SoundTouchHandle;

/**
 * 创建 SoundTouch 实例
 * @return SoundTouch 实例句柄
 */
SoundTouchHandle soundtouch_create();

/**
 * 销毁 SoundTouch 实例
 * @param handle SoundTouch 实例句柄
 */
void soundtouch_destroy(SoundTouchHandle handle);

/**
 * 设置采样率
 * @param handle SoundTouch 实例句柄
 * @param sampleRate 采样率 (例如: 44100, 48000)
 */
void soundtouch_set_sample_rate(SoundTouchHandle handle, unsigned int sampleRate);

/**
 * 设置声道数
 * @param handle SoundTouch 实例句柄
 * @param channels 声道数 (1=单声道, 2=立体声)
 */
void soundtouch_set_channels(SoundTouchHandle handle, unsigned int channels);

/**
 * 设置速率变化（影响速度和音调）
 * @param handle SoundTouch 实例句柄
 * @param rate 速率值 (1.0=正常, <1.0=变慢, >1.0=变快)
 */
void soundtouch_set_rate(SoundTouchHandle handle, double rate);

/**
 * 设置节奏变化（只影响速度，不影响音调）
 * @param handle SoundTouch 实例句柄
 * @param tempo 节奏值 (1.0=正常, <1.0=变慢, >1.0=变快)
 */
void soundtouch_set_tempo(SoundTouchHandle handle, double tempo);

/**
 * 设置速率变化百分比
 * @param handle SoundTouch 实例句柄
 * @param rateChange 速率变化百分比 (-50 到 +100)
 */
void soundtouch_set_rate_change(SoundTouchHandle handle, double rateChange);

/**
 * 设置节奏变化百分比
 * @param handle SoundTouch 实例句柄
 * @param tempoChange 节奏变化百分比 (-50 到 +100)
 */
void soundtouch_set_tempo_change(SoundTouchHandle handle, double tempoChange);

/**
 * 设置音调（只影响音调，不影响速度）
 * @param handle SoundTouch 实例句柄
 * @param pitch 音调值 (1.0=正常, <1.0=降低, >1.0=升高)
 */
void soundtouch_set_pitch(SoundTouchHandle handle, double pitch);

/**
 * 设置音调变化（八度）
 * @param handle SoundTouch 实例句柄
 * @param pitchOctaves 音调变化八度 (-1.0 到 +1.0)
 */
void soundtouch_set_pitch_octaves(SoundTouchHandle handle, double pitchOctaves);

/**
 * 设置音调变化（半音）
 * @param handle SoundTouch 实例句柄
 * @param pitchSemiTones 音调变化半音 (-12 到 +12)
 */
void soundtouch_set_pitch_semitones(SoundTouchHandle handle, double pitchSemiTones);

/**
 * 输入音频样本数据
 * @param handle SoundTouch 实例句柄
 * @param samples 样本数据指针
 * @param numSamples 样本数量（立体声时一个样本包含两个声道的数据）
 */
void soundtouch_put_samples(SoundTouchHandle handle, const float* samples, unsigned int numSamples);

/**
 * 接收处理后的音频样本数据
 * @param handle SoundTouch 实例句柄
 * @param output 输出缓冲区指针
 * @param maxSamples 最大接收样本数
 * @return 实际接收的样本数
 */
unsigned int soundtouch_receive_samples(SoundTouchHandle handle, float* output, unsigned int maxSamples);

/**
 * 刷新处理管道，输出剩余样本
 * @param handle SoundTouch 实例句柄
 */
void soundtouch_flush(SoundTouchHandle handle);

/**
 * 清空所有缓冲区
 * @param handle SoundTouch 实例句柄
 */
void soundtouch_clear(SoundTouchHandle handle);

/**
 * 获取可用的处理后样本数量
 * @param handle SoundTouch 实例句柄
 * @return 可用样本数
 */
unsigned int soundtouch_num_samples(SoundTouchHandle handle);

/**
 * 获取未处理的样本数量
 * @param handle SoundTouch 实例句柄
 * @return 未处理样本数
 */
unsigned int soundtouch_num_unprocessed_samples(SoundTouchHandle handle);

/**
 * 检查是否为空（没有可用样本）
 * @param handle SoundTouch 实例句柄
 * @return 1=空, 0=非空
 */
int soundtouch_is_empty(SoundTouchHandle handle);

/**
 * 获取输入输出样本比率
 * @param handle SoundTouch 实例句柄
 * @return 输入输出比率
 */
double soundtouch_get_input_output_sample_ratio(SoundTouchHandle handle);

/**
 * 获取版本字符串
 * @return 版本字符串
 */
const char* soundtouch_get_version_string();

/**
 * 获取版本ID
 * @return 版本ID
 */
unsigned int soundtouch_get_version_id();

/**
 * 设置处理参数
 * @param handle SoundTouch 实例句柄
 * @param settingId 设置ID
 * @param value 设置值
 * @return 1=成功, 0=失败
 */
int soundtouch_set_setting(SoundTouchHandle handle, int settingId, int value);

/**
 * 获取处理参数
 * @param handle SoundTouch 实例句柄
 * @param settingId 设置ID
 * @return 设置值
 */
int soundtouch_get_setting(SoundTouchHandle handle, int settingId);

#ifdef __cplusplus
}
#endif

#endif // SOUNDTOUCH_C_API_H
