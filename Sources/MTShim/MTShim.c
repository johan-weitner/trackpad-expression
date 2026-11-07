#include "MTShim.h"
#include <dlfcn.h>
#include <stdio.h>

static CFArrayRef (*p_MTDeviceCreateList)(void);
static void (*p_MTRegisterContactFrameCallback)(MTDeviceRef, MTContactCallback);
static void (*p_MTDeviceStart)(MTDeviceRef, int);
static void (*p_MTDeviceStop)(MTDeviceRef);
static bool (*p_MTDeviceIsBuiltIn)(MTDeviceRef);
static int  (*p_MTDeviceGetSensorSurfaceDimensions)(MTDeviceRef, int *, int *);
static int  (*p_MTDeviceGetDeviceID)(MTDeviceRef, uint64_t *);

#define RESOLVE(name) \
    do { \
        *(void **)(&p_##name) = dlsym(h, #name); \
        if (!p_##name && required) { snprintf(err, errLen, "missing symbol " #name); return false; } \
    } while (0)

bool mt_load(char *err, int errLen) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!h) { snprintf(err, errLen, "dlopen failed: %s", dlerror()); return false; }
    bool required = true;
    RESOLVE(MTDeviceCreateList);
    RESOLVE(MTRegisterContactFrameCallback);
    RESOLVE(MTDeviceStart);
    required = false; // nice-to-have
    RESOLVE(MTDeviceStop);
    RESOLVE(MTDeviceIsBuiltIn);
    RESOLVE(MTDeviceGetSensorSurfaceDimensions);
    RESOLVE(MTDeviceGetDeviceID);
    return true;
}

CFArrayRef mt_device_list(void) { return p_MTDeviceCreateList(); }

bool mt_is_builtin(MTDeviceRef dev) { return p_MTDeviceIsBuiltIn ? p_MTDeviceIsBuiltIn(dev) : false; }

bool mt_surface_size(MTDeviceRef dev, int *w, int *h) {
    if (!p_MTDeviceGetSensorSurfaceDimensions) return false;
    return p_MTDeviceGetSensorSurfaceDimensions(dev, w, h) == 0;
}

uint64_t mt_device_id(MTDeviceRef dev) {
    uint64_t id = 0;
    if (p_MTDeviceGetDeviceID) p_MTDeviceGetDeviceID(dev, &id);
    return id;
}

void mt_register(MTDeviceRef dev, MTContactCallback cb) { p_MTRegisterContactFrameCallback(dev, cb); }
void mt_start(MTDeviceRef dev) { p_MTDeviceStart(dev, 0); }
void mt_stop(MTDeviceRef dev) { if (p_MTDeviceStop) p_MTDeviceStop(dev); }
