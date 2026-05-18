#pragma once

struct OH_NativeXComponent;

namespace voxera {

bool EglPreviewStart(OH_NativeXComponent *component, void *window);
void EglPreviewResize(OH_NativeXComponent *component, void *window);
void EglPreviewStop();
bool EglPreviewIsActive();

} // namespace voxera
