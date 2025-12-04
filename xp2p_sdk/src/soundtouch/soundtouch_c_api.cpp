#include "soundtouch_c_api.h"
#include "SoundTouch.h"

using namespace soundtouch;

// 创建 SoundTouch 实例
SoundTouchHandle soundtouch_create() {
    return static_cast<SoundTouchHandle>(new SoundTouch());
}

// 销毁 SoundTouch 实例
void soundtouch_destroy(SoundTouchHandle handle) {
    if (handle) {
        delete static_cast<SoundTouch*>(handle);
    }
}

// 设置采样率
void soundtouch_set_sample_rate(SoundTouchHandle handle, unsigned int sampleRate) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setSampleRate(sampleRate);
    }
}

// 设置声道数
void soundtouch_set_channels(SoundTouchHandle handle, unsigned int channels) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setChannels(channels);
    }
}

// 设置速率
void soundtouch_set_rate(SoundTouchHandle handle, double rate) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setRate(rate);
    }
}

// 设置节奏
void soundtouch_set_tempo(SoundTouchHandle handle, double tempo) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setTempo(tempo);
    }
}

// 设置速率变化百分比
void soundtouch_set_rate_change(SoundTouchHandle handle, double rateChange) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setRateChange(rateChange);
    }
}

// 设置节奏变化百分比
void soundtouch_set_tempo_change(SoundTouchHandle handle, double tempoChange) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setTempoChange(tempoChange);
    }
}

// 设置音调
void soundtouch_set_pitch(SoundTouchHandle handle, double pitch) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setPitch(pitch);
    }
}

// 设置音调变化（八度）
void soundtouch_set_pitch_octaves(SoundTouchHandle handle, double pitchOctaves) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setPitchOctaves(pitchOctaves);
    }
}

// 设置音调变化（半音）
void soundtouch_set_pitch_semitones(SoundTouchHandle handle, double pitchSemiTones) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->setPitchSemiTones(pitchSemiTones);
    }
}

// 输入音频样本
void soundtouch_put_samples(SoundTouchHandle handle, const float* samples, unsigned int numSamples) {
    if (handle && samples) {
        static_cast<SoundTouch*>(handle)->putSamples(samples, numSamples);
    }
}

// 接收处理后的样本
unsigned int soundtouch_receive_samples(SoundTouchHandle handle, float* output, unsigned int maxSamples) {
    if (handle && output) {
        return static_cast<SoundTouch*>(handle)->receiveSamples(output, maxSamples);
    }
    return 0;
}

// 刷新处理管道
void soundtouch_flush(SoundTouchHandle handle) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->flush();
    }
}

// 清空缓冲区
void soundtouch_clear(SoundTouchHandle handle) {
    if (handle) {
        static_cast<SoundTouch*>(handle)->clear();
    }
}

// 获取可用样本数
unsigned int soundtouch_num_samples(SoundTouchHandle handle) {
    if (handle) {
        return static_cast<SoundTouch*>(handle)->numSamples();
    }
    return 0;
}

// 获取未处理样本数
unsigned int soundtouch_num_unprocessed_samples(SoundTouchHandle handle) {
    if (handle) {
        return static_cast<SoundTouch*>(handle)->numUnprocessedSamples();
    }
    return 0;
}

// 检查是否为空
int soundtouch_is_empty(SoundTouchHandle handle) {
    if (handle) {
        return static_cast<SoundTouch*>(handle)->isEmpty() ? 1 : 0;
    }
    return 1;
}

// 获取输入输出样本比率
double soundtouch_get_input_output_sample_ratio(SoundTouchHandle handle) {
    if (handle) {
        return static_cast<SoundTouch*>(handle)->getInputOutputSampleRatio();
    }
    return 1.0;
}

// 获取版本字符串
const char* soundtouch_get_version_string() {
    return SoundTouch::getVersionString();
}

// 获取版本ID
unsigned int soundtouch_get_version_id() {
    return SoundTouch::getVersionId();
}

// 设置处理参数
int soundtouch_set_setting(SoundTouchHandle handle, int settingId, int value) {
    if (handle) {
        return static_cast<SoundTouch*>(handle)->setSetting(settingId, value) ? 1 : 0;
    }
    return 0;
}

// 获取处理参数
int soundtouch_get_setting(SoundTouchHandle handle, int settingId) {
    if (handle) {
        return static_cast<SoundTouch*>(handle)->getSetting(settingId);
    }
    return 0;
}
