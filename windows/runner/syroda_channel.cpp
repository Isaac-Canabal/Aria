#include "syroda_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windows.h>

#include <memory>
#include <string>

namespace {

// Los mismos codigos que espera `OpenOutcome` en Dart. Se distinguen a
// proposito: "no esta" y "no hay con que abrirlo" son problemas distintos y
// la accion de la persona tambien.
constexpr char kOpened[] = "opened";
constexpr char kMissing[] = "missing";
constexpr char kNoHandler[] = "noHandler";
constexpr char kFailed[] = "failed";

std::wstring Utf16Of(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                   static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        wide.data(), size);
  return wide;
}

bool Exists(const std::wstring& path) {
  return ::GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES;
}

// Abre con la aplicacion asociada. `ShellExecuteW` devuelve un valor <= 32
// cuando falla; solo dos casos importan lo bastante como para separarlos.
std::string OpenWithShell(const std::wstring& path) {
  if (!Exists(path)) return kMissing;

  HINSTANCE code = ::ShellExecuteW(nullptr, L"open", path.c_str(), nullptr,
                                   nullptr, SW_SHOWNORMAL);
  auto value = reinterpret_cast<INT_PTR>(code);
  if (value > 32) return kOpened;

  switch (value) {
    case SE_ERR_NOASSOC:
    case SE_ERR_ASSOCINCOMPLETE:
      return kNoHandler;
    case ERROR_FILE_NOT_FOUND:
    case ERROR_PATH_NOT_FOUND:
      return kMissing;
    default:
      return kFailed;
  }
}

// Abre el Explorador con el archivo ya seleccionado, que es mas util que
// dejar a la persona buscandolo en una carpeta llena.
std::string RevealInExplorer(const std::wstring& path) {
  if (!Exists(path)) return kMissing;

  PIDLIST_ABSOLUTE item = ::ILCreateFromPathW(path.c_str());
  if (item == nullptr) return kFailed;

  HRESULT hr = ::SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
  ::ILFree(item);
  return SUCCEEDED(hr) ? kOpened : kFailed;
}

std::string OpenFolder(const std::wstring& path) {
  if (!Exists(path)) return kMissing;
  HINSTANCE code = ::ShellExecuteW(nullptr, L"open", path.c_str(), nullptr,
                                   nullptr, SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(code) > 32 ? kOpened : kFailed;
}

const std::string* StringArgument(const flutter::EncodableValue* arguments,
                                  const char* key) {
  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) return nullptr;
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) return nullptr;
  return std::get_if<std::string>(&it->second);
}

}  // namespace

void RegisterSyrodaChannel(flutter::FlutterEngine* engine) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "syroda/platform",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        const std::string* target = StringArgument(call.arguments(), "target");

        if (call.method_name() == "openFile") {
          if (target == nullptr) {
            result->Error("no_target", "falta el argumento target");
            return;
          }
          result->Success(flutter::EncodableValue(OpenWithShell(Utf16Of(*target))));
          return;
        }

        if (call.method_name() == "revealFile") {
          if (target == nullptr) {
            result->Error("no_target", "falta el argumento target");
            return;
          }
          result->Success(
              flutter::EncodableValue(RevealInExplorer(Utf16Of(*target))));
          return;
        }

        if (call.method_name() == "openDestinationFolder") {
          if (target == nullptr) {
            result->Error("no_target", "falta el argumento target");
            return;
          }
          result->Success(flutter::EncodableValue(OpenFolder(Utf16Of(*target))));
          return;
        }

        result->NotImplemented();
      });

  // El canal vive lo que viva el motor.
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      retained;
  retained = std::move(channel);
}
