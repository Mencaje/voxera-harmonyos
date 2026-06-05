#pragma once

struct OH_NativeXComponent;

namespace voxera {

void SetAppDataPaths(const char *shareDir, const char *cacheDir, const char *userDir);
void SetPublicUserDataDir(const char *publicUserDir);
void SetDeviceFormFactor(const char *deviceType);
void OnSurfaceCreated(OH_NativeXComponent *component, void *window);
void OnSurfaceChanged(OH_NativeXComponent *component, void *window);
void OnSurfaceDestroyed();
const char *GetEngineStatus();

} // namespace voxera
