#include "luanti_host.h"
#include "xcomponent_bridge.h"

#include <hilog/log.h>
#include <napi/native_api.h>

#include <string>

#if VOXERA_LINK_LUANTI
#include "porting_ohos.h"
#endif

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "VoxeraNapi"

namespace {

napi_value NapiGetEngineStatus(napi_env env, napi_callback_info /*info*/)
{
    napi_value result;
    napi_create_string_utf8(env, voxera::GetEngineStatus(), NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value NapiIsInGameWorld(napi_env env, napi_callback_info /*info*/)
{
    bool inWorld = false;
#if VOXERA_LINK_LUANTI
    inWorld = porting::ohosIsInGameWorld();
#endif
    napi_value result;
    napi_get_boolean(env, inWorld, &result);
    return result;
}

napi_value NapiIsPlayerInventoryOpen(napi_env env, napi_callback_info /*info*/)
{
    bool open = false;
#if VOXERA_LINK_LUANTI
    open = porting::ohosIsPlayerInventoryOpen();
#endif
    napi_value result;
    napi_get_boolean(env, open, &result);
    return result;
}

#if VOXERA_LINK_LUANTI
napi_value NapiPollOhosUiRequest(napi_env env, napi_callback_info /*info*/)
{
    std::string payload;
    const int kind = porting::ohosPollUiRequest(payload);

    napi_value result;
    napi_create_object(env, &result);

    napi_value kindVal;
    napi_create_int32(env, kind, &kindVal);
    napi_set_named_property(env, result, "kind", kindVal);

    napi_value payloadVal;
    napi_create_string_utf8(env, payload.c_str(), NAPI_AUTO_LENGTH, &payloadVal);
    napi_set_named_property(env, result, "payload", payloadVal);

    return result;
}

napi_value NapiCompleteOhosCopyDir(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    bool ok = false;
    napi_get_value_bool(env, args[0], &ok);

    porting::ohosCompleteCopyDir(ok);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiCompleteOhosTextInput(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    bool canceled = false;
    napi_get_value_bool(env, args[0], &canceled);

    size_t textLen = 0;
    napi_get_value_string_utf8(env, args[1], nullptr, 0, &textLen);
    std::string text(textLen + 1, '\0');
    napi_get_value_string_utf8(env, args[1], text.data(), textLen + 1, &textLen);
    text.resize(textLen);

    porting::ohosCompleteTextInput(canceled, text);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiCompleteOhosFilePick(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t formLen = 0;
    size_t pathLen = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &formLen);
    napi_get_value_string_utf8(env, args[1], nullptr, 0, &pathLen);

    std::string formname(formLen + 1, '\0');
    std::string path(pathLen + 1, '\0');
    napi_get_value_string_utf8(env, args[0], formname.data(), formLen + 1, &formLen);
    napi_get_value_string_utf8(env, args[1], path.data(), pathLen + 1, &pathLen);
    formname.resize(formLen);
    path.resize(pathLen);

    porting::ohosCompleteFilePick(formname, path);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
            "completeOhosFilePick %{public}s len=%{public}u",
            formname.c_str(), static_cast<unsigned>(path.size()));

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiGetOhosZipDropTarget(napi_env env, napi_callback_info /*info*/)
{
    const std::string target = porting::ohosGetZipDropTarget();
    napi_value result;
    napi_create_string_utf8(env, target.c_str(), NAPI_AUTO_LENGTH, &result);
    return result;
}
#endif

napi_value NapiTriggerPhoneGameAction(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t action = 0;
    napi_get_value_int32(env, args[0], &action);

#if VOXERA_LINK_LUANTI
    porting::ohosQueuePhoneGameAction(action);
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiInjectKeyEvent(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t keycode = 0;
    bool down = false;
    napi_get_value_int32(env, args[0], &keycode);
    napi_get_value_bool(env, args[1], &down);

#if VOXERA_LINK_LUANTI
    porting::ohosInjectKeyEvent(keycode, down);
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiInjectMouseMotion(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t dx = 0;
    int32_t dy = 0;
    napi_get_value_int32(env, args[0], &dx);
    napi_get_value_int32(env, args[1], &dy);

#if VOXERA_LINK_LUANTI
    porting::ohosInjectMouseMotion(dx, dy);
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiInjectClick(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    double x = 0.0;
    double y = 0.0;
    napi_get_value_double(env, args[0], &x);
    napi_get_value_double(env, args[1], &y);

#if VOXERA_LINK_LUANTI
    porting::ohosInjectClick(static_cast<float>(x), static_cast<float>(y));
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiInjectTouch(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    double x = 0.0;
    double y = 0.0;
    int32_t action = 0;
    int32_t fingerId = 0;
    napi_get_value_double(env, args[0], &x);
    napi_get_value_double(env, args[1], &y);
    napi_get_value_int32(env, args[2], &action);
    napi_get_value_int32(env, args[3], &fingerId);

#if VOXERA_LINK_LUANTI
    porting::ohosInjectTouch(static_cast<float>(x), static_cast<float>(y), action, fingerId);
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiSetAppDataPaths(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t shareLen = 0;
    size_t cacheLen = 0;
    size_t userLen = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &shareLen);
    napi_get_value_string_utf8(env, args[1], nullptr, 0, &cacheLen);
    napi_get_value_string_utf8(env, args[2], nullptr, 0, &userLen);

    std::string shareDir(shareLen + 1, '\0');
    std::string cacheDir(cacheLen + 1, '\0');
    std::string userDir(userLen + 1, '\0');
    napi_get_value_string_utf8(env, args[0], shareDir.data(), shareLen + 1, &shareLen);
    napi_get_value_string_utf8(env, args[1], cacheDir.data(), cacheLen + 1, &cacheLen);
    napi_get_value_string_utf8(env, args[2], userDir.data(), userLen + 1, &userLen);
    shareDir.resize(shareLen);
    cacheDir.resize(cacheLen);
    userDir.resize(userLen);

    voxera::SetAppDataPaths(shareDir.c_str(), cacheDir.c_str(), userDir.c_str());

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiSetPublicUserDataDir(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &len);

    std::string path(len + 1, '\0');
    napi_get_value_string_utf8(env, args[0], path.data(), len + 1, &len);
    path.resize(len);

    voxera::SetPublicUserDataDir(path.c_str());

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiSetDeviceFormFactor(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t len = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &len);

    std::string deviceType(len + 1, '\0');
    napi_get_value_string_utf8(env, args[0], deviceType.data(), len + 1, &len);
    deviceType.resize(len);

    voxera::SetDeviceFormFactor(deviceType.c_str());

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiGetNativePauseActive(napi_env env, napi_callback_info /*info*/)
{
    bool active = false;
#if VOXERA_LINK_LUANTI
    active = porting::ohosGetNativePauseActive();
#endif
    napi_value result;
    napi_get_boolean(env, active, &result);
    return result;
}

napi_value NapiSetNativePauseActive(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    bool active = false;
    napi_get_value_bool(env, args[0], &active);

#if VOXERA_LINK_LUANTI
    porting::ohosSetNativePauseActive(active);
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiNativePauseExitMenu(napi_env env, napi_callback_info /*info*/)
{
#if VOXERA_LINK_LUANTI
    porting::ohosNativePauseExitMenu();
#endif
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value NapiNativePauseExitOS(napi_env env, napi_callback_info /*info*/)
{
#if VOXERA_LINK_LUANTI
    porting::ohosNativePauseExitOS();
#endif
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value Init(napi_env env, napi_value exports)
{
    // XComponent invokes Init with OH_NATIVE_XCOMPONENT_OBJ; ArkTS import does not.
    if (voxera::InitXComponentBridge(env, exports)) {
        OH_LOG_INFO(LOG_APP, "XComponent bridge ready");
    }

    napi_property_descriptor props[] = {
        {"getEngineStatus", nullptr, NapiGetEngineStatus, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isInGameWorld", nullptr, NapiIsInGameWorld, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isPlayerInventoryOpen", nullptr, NapiIsPlayerInventoryOpen, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setAppDataPaths", nullptr, NapiSetAppDataPaths, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setPublicUserDataDir", nullptr, NapiSetPublicUserDataDir, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setDeviceFormFactor", nullptr, NapiSetDeviceFormFactor, nullptr, nullptr, nullptr, napi_default, nullptr},
#if VOXERA_LINK_LUANTI
        {"pollOhosUiRequest", nullptr, NapiPollOhosUiRequest, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"completeOhosFilePick", nullptr, NapiCompleteOhosFilePick, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"completeOhosCopyDir", nullptr, NapiCompleteOhosCopyDir, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"completeOhosTextInput", nullptr, NapiCompleteOhosTextInput, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getOhosZipDropTarget", nullptr, NapiGetOhosZipDropTarget, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"injectKeyEvent", nullptr, NapiInjectKeyEvent, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"triggerPhoneGameAction", nullptr, NapiTriggerPhoneGameAction, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"injectMouseMotion", nullptr, NapiInjectMouseMotion, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"injectTouch", nullptr, NapiInjectTouch, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"injectClick", nullptr, NapiInjectClick, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getNativePauseActive", nullptr, NapiGetNativePauseActive, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setNativePauseActive", nullptr, NapiSetNativePauseActive, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativePauseExitMenu", nullptr, NapiNativePauseExitMenu, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativePauseExitOS", nullptr, NapiNativePauseExitOS, nullptr, nullptr, nullptr, napi_default, nullptr},
#endif
    };
    napi_define_properties(env, exports, sizeof(props) / sizeof(props[0]), props);
    return exports;
}

napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = {0},
};

} // namespace

extern "C" __attribute__((constructor)) void RegisterVoxeraEntryModule(void)
{
    napi_module_register(&g_module);
}
