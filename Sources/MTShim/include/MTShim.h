// Declarations for Apple's private MultitouchSupport.framework.
// Layout is reverse-engineered (used by BetterTouchTool, OpenMultitouchSupport, etc.)
// and is not guaranteed by Apple.
#pragma once
#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;

typedef struct {
    int      frame;
    double   timestamp;
    int      identifier;   // stable per finger while it stays down
    int      state;        // 1..7: not-tracking, start, hover, make-touch, touching, break, linger, out
    int      fingerId;
    int      handId;
    MTVector normalized;   // position 0..1, origin bottom-left
    float    size;
    int      zero1;
    float    angle;
    float    majorAxis;
    float    minorAxis;
    MTVector absolute;     // millimetres
    int      zero2[2];
    float    density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef device, const MTTouch *touches,
                                 int numTouches, double timestamp, int frame);

/// Loads the framework and resolves symbols. Returns false (and fills err) on failure.
bool mt_load(char *err, int errLen);

/// Returns a CFArray of MTDeviceRef (caller owns it), or NULL.
CFArrayRef mt_device_list(void) CF_RETURNS_RETAINED;
bool mt_is_builtin(MTDeviceRef dev);
/// Surface size in hundredths of a millimetre. Returns false if unavailable.
bool mt_surface_size(MTDeviceRef dev, int *width, int *height);
uint64_t mt_device_id(MTDeviceRef dev);
void mt_register(MTDeviceRef dev, MTContactCallback cb);
void mt_start(MTDeviceRef dev);
void mt_stop(MTDeviceRef dev);
