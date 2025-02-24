#include <iostream>
#include <string>
#include <windows.h>
#include <tlhelp32.h>
#include <fstream>
#include <chrono>
#include <thread>
#include <nlohmann/json.hpp>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "mmdevapi.lib")

using json = nlohmann::json;

struct DECLSPEC_UUID("F8679F50-850A-41CF-9C72-430F290290C8") IPolicyConfig : IUnknown {
    virtual HRESULT STDMETHODCALLTYPE GetMixFormat(LPCWSTR, WAVEFORMATEX**) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetDeviceFormat(LPCWSTR, INT, WAVEFORMATEX**) = 0;
    virtual HRESULT STDMETHODCALLTYPE ResetDeviceFormat(LPCWSTR) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetDeviceFormat(LPCWSTR, WAVEFORMATEX*, WAVEFORMATEX*) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetProcessingPeriod(LPCWSTR, INT, PINT64, PINT64) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetProcessingPeriod(LPCWSTR, PINT64) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetShareMode(LPCWSTR, struct DeviceShareMode*) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetShareMode(LPCWSTR, struct DeviceShareMode*) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetPropertyValue(LPCWSTR, const PROPERTYKEY&, PROPVARIANT*) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetPropertyValue(LPCWSTR, const PROPERTYKEY&, PROPVARIANT*) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetDefaultEndpoint(LPCWSTR pszDeviceId, ERole eRole) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetEndpointVisibility(LPCWSTR, BOOL) = 0;
};

const CLSID CLSID_PolicyConfigClient =
{ 0x870af99c, 0x171d, 0x4f9e, {0xaf, 0x0d, 0xe6, 0x3d, 0xf4, 0x0c, 0x2b, 0xc9} };

// Audio Device structure
struct AudioDevice {
    std::string ID;
    std::string Name;

    AudioDevice() : ID(""), Name("") {}
};

// COM initialization helper
class CoInitializeGuard {
public:
    CoInitializeGuard() {
        HRESULT hr = CoInitialize(nullptr);
        if (FAILED(hr)) throw std::runtime_error("Failed to initialize COM");
    }
    ~CoInitializeGuard() { CoUninitialize(); }
};

// Wide string to UTF-8 conversion (replacing CW2A)
std::string WideToUTF8(LPCWSTR wideStr) {
    if (!wideStr) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, wideStr, -1, nullptr, 0, nullptr, nullptr);
    if (size == 0) return "";
    std::string result(size - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, wideStr, -1, &result[0], size, nullptr, nullptr);
    return result;
}

// Get Audio Device implementation
AudioDevice GetAudioDevice(bool playback, bool communication) {
    AudioDevice dev;
    HRESULT hr;
    IMMDeviceEnumerator* pEnumerator = nullptr;
    IMMDevice* pDevice = nullptr;
    IPropertyStore* pProps = nullptr;

    CoInitializeGuard comGuard;

    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
    if (FAILED(hr)) throw std::runtime_error("Failed to create device enumerator");

    ERole role = communication ? eCommunications : eConsole;
    EDataFlow flow = playback ? eRender : eCapture;

    hr = pEnumerator->GetDefaultAudioEndpoint(flow, role, &pDevice);
    if (FAILED(hr)) {
        pEnumerator->Release();
        throw std::runtime_error("Failed to get default audio endpoint");
    }

    LPWSTR pwszID = nullptr;
    hr = pDevice->GetId(&pwszID);
    if (SUCCEEDED(hr)) {
        dev.ID = WideToUTF8(pwszID);
        CoTaskMemFree(pwszID);
    }

    hr = pDevice->OpenPropertyStore(STGM_READ, &pProps);
    if (SUCCEEDED(hr)) {
        PROPVARIANT varName;
        PropVariantInit(&varName);
        hr = pProps->GetValue(PKEY_Device_FriendlyName, &varName);
        if (SUCCEEDED(hr)) {
            dev.Name = WideToUTF8(varName.pwszVal);
            PropVariantClear(&varName);
        }
        pProps->Release();
    }

    pDevice->Release();
    pEnumerator->Release();
    return dev;
}

// Set Audio Device implementation
bool SetAudioDevice(const std::string& id, bool defaultOnly, bool communicationOnly) {
    HRESULT hr;
    IMMDeviceEnumerator* pEnumerator = nullptr;
    IMMDevice* pDevice = nullptr;
    IPolicyConfig* pPolicyConfig = nullptr;

    CoInitializeGuard comGuard;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);
    if (FAILED(hr)) return false;

    hr = pEnumerator->GetDevice(std::wstring(id.begin(), id.end()).c_str(), &pDevice);
    if (FAILED(hr)) {
        pEnumerator->Release();
        return false;
    }

    hr = CoCreateInstance(CLSID_PolicyConfigClient, nullptr, CLSCTX_ALL,
        __uuidof(IPolicyConfig), (void**)&pPolicyConfig);
    if (FAILED(hr)) {
        pDevice->Release();
        pEnumerator->Release();
        return false;
    }

    ERole role = communicationOnly ? eCommunications : eConsole;
    if (defaultOnly && !communicationOnly) {
        hr = pPolicyConfig->SetDefaultEndpoint(std::wstring(id.begin(), id.end()).c_str(), eConsole);
    }
    if (communicationOnly) {
        hr = pPolicyConfig->SetDefaultEndpoint(std::wstring(id.begin(), id.end()).c_str(), eCommunications);
    }

    bool success = SUCCEEDED(hr);
    pPolicyConfig->Release();
    pDevice->Release();
    pEnumerator->Release();
    return success;
}

class AudioMonitor {
private:
    int pollingInterval;
    bool force;
    std::string permanentFolder;
    std::string logFile;
    std::string defaultsFile;
    json savedDefaults;

    void SetProcessPriority() {
        HANDLE hProcess = GetCurrentProcess();
        SetProcessAffinityMask(hProcess, 1);
        SetPriorityClass(hProcess, BELOW_NORMAL_PRIORITY_CLASS);
    }

    void InitializePaths() {
        char* appData;
        size_t len;
        _dupenv_s(&appData, &len, "APPDATA");
        permanentFolder = std::string(appData) + "\\StaticAudioDevices";
        logFile = permanentFolder + "\\log.log";
        defaultsFile = permanentFolder + "\\default_audio.json";
        free(appData);

        DWORD attribs = GetFileAttributesA(permanentFolder.c_str());
        if (attribs == INVALID_FILE_ATTRIBUTES) {
            CreateDirectoryA(permanentFolder.c_str(), nullptr);
        }
    }

    void RotateLog() {
        std::ifstream logCheck(logFile, std::ios::binary | std::ios::ate);
        if (logCheck.good() && logCheck.tellg() > 1024 * 1024) { // 1MB
            logCheck.close();
            DeleteFileA((logFile + ".old").c_str());
            MoveFileA(logFile.c_str(), (logFile + ".old").c_str());
        }
    }

    json GetCurrentDefaults() {
        try {
            return {
                {"Playback", {{"ID", GetAudioDevice(true, false).ID}, {"Name", GetAudioDevice(true, false).Name}}},
                {"PlaybackCommunication", {{"ID", GetAudioDevice(true, true).ID}, {"Name", GetAudioDevice(true, true).Name}}},
                {"Recording", {{"ID", GetAudioDevice(false, false).ID}, {"Name", GetAudioDevice(false, false).Name}}},
                {"RecordingCommunication", {{"ID", GetAudioDevice(false, true).ID}, {"Name", GetAudioDevice(false, true).Name}}}
            };
        }
        catch (const std::exception& e) {
            std::cerr << "Failed to get current audio devices: " << e.what() << std::endl;
            return nullptr;
        }
    }

    void SaveDefaultDevices(const json& currentDefaults) {
        std::ofstream out(defaultsFile);
        out << currentDefaults.dump(4);
        out.close();
        savedDefaults = currentDefaults;
    }

public:
    AudioMonitor(int interval = 5, bool f = false) : pollingInterval(interval), force(f) {
        SetProcessPriority();
        InitializePaths();
        RotateLog();
    }

    void Start() {
        std::cout << "Initializing audio device monitoring..." << std::endl;

        std::ifstream check(defaultsFile);
        if (!check.good() || force) {
            std::cout << "Determining and saving default audio devices..." << std::endl;
            json currentDefaults = GetCurrentDefaults();
            if (currentDefaults.is_null()) {
                std::cerr << "Failed to get initial defaults" << std::endl;
                return;
            }
            SaveDefaultDevices(currentDefaults);
            std::cout << "Saved defaults: " << savedDefaults.dump(4) << std::endl;
        }
        else {
            std::cout << "Loading saved default audio devices..." << std::endl;
            check.close();
            std::ifstream in(defaultsFile);
            in >> savedDefaults;
            in.close();
        }

        std::cout << "Start monitoring audio devices..." << std::endl;

        json deviceChecks = {
            {"Playback", {{"Default", true}, {"Communication", false}}},
            {"PlaybackCommunication", {{"Default", false}, {"Communication", true}}},
            {"Recording", {{"Default", true}, {"Communication", false}}},
            {"RecordingCommunication", {{"Default", false}, {"Communication", true}}}
        };

        while (true) {
            try {
                json current = GetCurrentDefaults();
                if (current.is_null()) {
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                    continue;
                }

                for (auto it = deviceChecks.begin(); it != deviceChecks.end(); ++it) {
                    std::string device = it.key();
                    json checks = it.value();
                    if (current[device]["ID"] != savedDefaults[device]["ID"]) {
                        std::cout << device << " device changed from '" << savedDefaults[device]["Name"]
                            << "' to '" << current[device]["Name"] << "'. Restoring default..." << std::endl;
                        SetAudioDevice(savedDefaults[device]["ID"], checks["Default"], checks["Communication"]);
                    }
                }

                std::this_thread::sleep_for(std::chrono::seconds(pollingInterval));
            }
            catch (const std::exception& e) {
                std::cerr << "Error in main loop: " << e.what() << std::endl;
                std::this_thread::sleep_for(std::chrono::seconds(1));
                return;
            }
        }
    }
};

int main(int argc, char* argv[]) {
    int pollingInterval = 3;
    bool force = false;

    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "-PollingInterval" && i + 1 < argc) {
            pollingInterval = std::stoi(argv[++i]);
        }
        else if (std::string(argv[i]) == "-Force") {
            force = true;
        }
    }

    AudioMonitor monitor(pollingInterval, force);
    monitor.Start();
    return 0;
}