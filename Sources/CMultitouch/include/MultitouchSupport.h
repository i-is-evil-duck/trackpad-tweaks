#ifndef CMULTITOUCH_MULTITOUCHSUPPORT_H
#define CMULTITOUCH_MULTITOUCHSUPPORT_H

#include <CoreFoundation/CoreFoundation.h>

// Community-standard reverse-engineered layout of Apple's private
// MultitouchSupport.framework. Field layout is load-bearing — do not reorder.

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position; MTPoint velocity; } MTVector;

typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;
    int fingerId;
    int handId;
    MTVector normalizedVector;
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absoluteVector;
    int zero2;
    int zero3;
    float zDensity;
} Finger;

typedef void *MTDeviceRef;

typedef int (*MTContactCallbackFunction)(MTDeviceRef device,
                                         Finger *fingers,
                                         int numFingers,
                                         double timestamp,
                                         int frame);

MTDeviceRef MTDeviceCreateDefault(void);
CFArrayRef MTDeviceCreateList(void);
void MTRegisterContactFrameCallback(MTDeviceRef device, MTContactCallbackFunction callback);
void MTUnregisterContactFrameCallback(MTDeviceRef device, MTContactCallbackFunction callback);
void MTDeviceStart(MTDeviceRef device, int unknown);
void MTDeviceStop(MTDeviceRef device);
bool MTDeviceIsRunning(MTDeviceRef device);

#endif
