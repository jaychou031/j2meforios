#pragma once
#include <cstdint>
#include <vector>
using OSStatus=int32_t; using UInt32=uint32_t;
constexpr OSStatus noErr=0;
constexpr int kAudioFormatLinearPCM=1,kLinearPCMFormatFlagIsSignedInteger=2,kAudioFormatFlagIsPacked=4,kAudioQueueParam_Volume=1;
struct AudioStreamBasicDescription { double mSampleRate; UInt32 mFormatID,mFormatFlags,mBytesPerPacket,mFramesPerPacket,mBytesPerFrame,mChannelsPerFrame,mBitsPerChannel; };
struct Buffer { void *mAudioData=nullptr; UInt32 mAudioDataByteSize=0; void *mUserData=nullptr; };
using AudioQueueBufferRef=Buffer*;
struct Queue;
using AudioQueueRef=Queue*;
using Callback=void(*)(void*,AudioQueueRef,AudioQueueBufferRef);
struct Queue { Callback callback; void *context; std::vector<Buffer*> allocated,ready; bool started=false,disposing=false; };
OSStatus AudioQueueNewOutput(const AudioStreamBasicDescription*,Callback,void*,void*,void*,UInt32,AudioQueueRef*);
OSStatus AudioQueueAllocateBuffer(AudioQueueRef,UInt32,AudioQueueBufferRef*);
OSStatus AudioQueueEnqueueBuffer(AudioQueueRef,AudioQueueBufferRef,UInt32,const void*);
OSStatus AudioQueueStart(AudioQueueRef,const void*);
OSStatus AudioQueuePause(AudioQueueRef);
OSStatus AudioQueueDispose(AudioQueueRef,bool);
OSStatus AudioQueueSetParameter(AudioQueueRef,int,float);
