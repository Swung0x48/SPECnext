#include "napi/native_api.h"
#include <cassert>
#include <cstddef>
#include <mutex>
#include <rawfile/raw_file.h>
#include <rawfile/raw_dir.h>
#include <rawfile/raw_file_manager.h>
#include <hilog/log.h>

#include <cstring>

#include <qos/qos.h>

#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <vector>
#include <filesystem>
#include <dlfcn.h>

#include <sys/stat.h>
#include <thread>
#include <chrono>

#include <sched.h>
#include <pthread.h>

#define SANDBOX_PATH "/data/storage/el2/base/haps/entry/files"

#define TEST_GLOBAL -1

const unsigned int LOG_PRINT_DOMAIN = 0xFF00;

typedef int (* specmain_t)(int argc, const char *argv[]);
typedef void (* specinit_t)();
typedef void (* specfinalize_t)();

std::thread t;
double time_elapsed = -1;

std::mutex g_mutex;

enum class status_t: int32_t {
    Skipped = 0,
    Pending,
    Initializing,
    Running,
    Failed,
    Completed,
    Error,
    Idle
};

struct state_t {
    status_t status = status_t::Skipped;
    double time = 0.;
    std::string message = "";
};

std::unordered_map<size_t, state_t> test_states;

std::unordered_map<size_t, std::string> test_names{
    {500, "500.perlbench_r"},
    {502, "502.gcc_r"},
    {505, "505.mcf_r"},
    {520, "520.omnetpp_r"},
    {523, "523.xalancbmk_r"},
    {525, "525.x264_r"},
    {531, "531.deepsjeng_r"},
    {541, "541.leela_r"},
    {548, "548.exchange2_r"},
    {557, "557.xz_r"},
    
    {503, "503.bwaves_r"},
    {507, "507.cactuBSSN_r"},
    {508, "508.namd_r"},
    {510, "510.parest_r"},
    {511, "511.povray_r"},
    {519, "519.lbm_r"},
    {521, "521.wrf_r"},
    {526, "526.blender_r"},
    {527, "527.cam4_r"},
    {538, "538.imagick_r"},
    {544, "544.nab_r"},
    {549, "549.fotonik3d_r"},
    {554, "554.roms_r"},
};

std::unordered_map<size_t, std::vector<std::vector<const char*>>> test_cmdline{
    {500, std::vector<std::vector<const char*>>{
            {"libperlbench_r.so", "-I./lib", "checkspam.pl", "2500", "5", "25", "11", "150", "1", "1", "1", "1"},
            {"libperlbench_r.so", "-I./lib", "diffmail.pl", "4", "800", "10", "17", "19", "300"},
            {"libperlbench_r.so", "-I./lib", "splitmail.pl", "6400", "12", "26", "16", "100", "0"},
        }
    },
    {502, std::vector<std::vector<const char*>>{
            {"libgcc_r.so", "gcc-pp.c", "-O3", "-finline-limit=0", "-fif-conversion", "-fif-conversion2", "-o", "gcc-pp.opts-O3_-finline-limit_0_-fif-conversion_-fif-conversion2.s"},
            {"libgcc_r.so", "gcc-smaller.c", "-O3", "-fipa-pta", "-o", "gcc-smaller.opts-O3_-fipa-pta.s"},
            {"libgcc_r.so", "ref32.c", "-O5", "-o", "ref32.opts-O5.s"},
            {"libgcc_r.so", "ref32.c", "-O3", "-fselective-scheduling", "-fselective-scheduling2", "-o", "ref32.opts-O3_-fselective-scheduling_-fselective-scheduling2.s"},
        }
    },
    {505, std::vector<std::vector<const char*>>{{"libmcf_r.so", "inp.in"}}},
    
    {520, std::vector<std::vector<const char*>>{{"libomnetpp_r.so", "-c", "General", "-r", "0"}}},
    {523, std::vector<std::vector<const char*>>{{{"libxalancbmk_r.so", "-v", "t5.xml", "xalanc.xsl"}}}},
    {525, std::vector<std::vector<const char*>>{
            {"libx264_r.so", "--pass", "1", "--stats", "x264_stats.log", "--bitrate", "1000", "--frames", "1000", "-o", "BuckBunny_New.264", "BuckBunny.yuv", "1280x720"},
            {"libx264_r.so", "--pass", "2", "--stats", "x264_stats.log", "--bitrate", "1000", "--dumpyuv", "200", "--frames", "1000", "-o", "BuckBunny_New.264", "BuckBunny.yuv", "1280x720"},
            {"libx264_r.so", "--seek", "500", "--dumpyuv", "200", "--frames", "1250", "-o", "BuckBunny_New.264", "BuckBunny.yuv", "1280x720"}
        }
    },
    {531, std::vector<std::vector<const char*>>{{{"libdeepsjeng_r.so", "ref.txt"}}}},
    {557, std::vector<std::vector<const char*>>{
            {"libxz_r.so", "cld.tar.xz", "160", "19cf30ae51eddcbefda78dd06014b4b96281456e078ca7c13e1c0c9e6aaea8dff3efb4ad6b0456697718cede6bd5454852652806a657bb56e07d61128434b474", "59796407", "61004416", "6"},
            {"libxz_r.so", "cpu2006docs.tar.xz", "250", "055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae", "23047774", "23513385", "6e"},
            {"libxz_r.so", "input.combined.xz", "250", "a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf", "40401484", "41217675", "7"},
        }
    },
    
    {508, std::vector<std::vector<const char*>>{{"libnamd_r.so", "--input", "apoa1.input", "--output", "apoa1.ref.output", "--iterations", "65"}}},
    {510, std::vector<std::vector<const char*>>{{"libparest_r.so", "ref.prm"}}},
    {511, std::vector<std::vector<const char*>>{{"libpovray_r.so", "SPEC-benchmark-ref.ini"}}},
    {519, std::vector<std::vector<const char*>>{{"liblbm_r.so", "3000", "reference.dat", "0", "0", "100_100_130_ldc.of"}}},
    {526, std::vector<std::vector<const char*>>{{"libblender_r.so", "sh3_no_char.blend", "--render-output", "sh3_no_char_", "--threads", "1", "-b", "-F", "RAWTGA", "-s", "849", "-e", "849", "-a"}}},
    {538, std::vector<std::vector<const char*>>{{"libimagick_r.so", "-limit", "disk", "0", "refrate_input.tga", "-edge", "41", "-resample", "181%", "-emboss", "31", "-colorspace", "YUV", "-mean-shift", "19x19+15%", "-resize", "30%", "refrate_output.tga"}}},
    {541, std::vector<std::vector<const char*>>{{"libleela_r.so", "ref.sgf"}}},
    {544, std::vector<std::vector<const char*>>{{"libnab_r.so", "1am0", "1122214447", "122"}}},
};

static napi_value Add(napi_env env, napi_callback_info info)
{
    napi_value nret;
    napi_create_double(env, (double)0, &nret);

    return nret;

}

static napi_value Query(napi_env env, napi_callback_info info)
{
    napi_value nret;

    std::lock_guard<std::mutex> lk(g_mutex);

    napi_create_double(env, time_elapsed, &nret);
    
    return nret;
}

napi_threadsafe_function g_log_callback = NULL;

napi_status do_log_update(int test_no) {
    if (g_log_callback != nullptr) {
        auto ret = napi_call_threadsafe_function(g_log_callback, (void*)test_no, napi_tsfn_blocking);
        assert(ret == napi_ok);
        return ret;
    }
    return napi_ok;
}

std::string g_uimsg;

void Callback(napi_env env, napi_value js_fun, void *context, void *data) {
    int testNo = (size_t)data;

    auto name = test_names[testNo];
    auto status = test_states[testNo].status;
    auto time = test_states[testNo].time;
    auto errormsg = test_states[testNo].message;

    int argc = 4;
    napi_value args[4] = {nullptr};

    napi_create_int32(env, (int)status, &args[0]);
    napi_create_int32(env, testNo, &args[1]);
    napi_create_double(env, time, &args[2]);
    g_uimsg = errormsg;

    napi_create_string_utf8(env, g_uimsg.c_str(), NAPI_AUTO_LENGTH, &args[3]);
    napi_value result = nullptr;
    napi_call_function(env, nullptr, /*func=*/js_fun, argc, args, &result);
}

static napi_value RunTests(napi_env env, napi_callback_info info) {
    size_t argc = 3;

    // [test_list, cpu, callback_func]
    napi_value args[3] = {nullptr};

    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    uint32_t length = 0;
    napi_get_array_length(env, args[0], &length);

    std::vector<int> test_list;
    for (uint32_t i = 0; i < length; ++i) {
        napi_value result;
        napi_get_element(env, args[0], i, &result);
        int test_no = 0;
        napi_get_value_int32(env, result, &test_no);
        test_list.emplace_back(test_no);
    }
    
    int cpu = -1;
    napi_get_value_int32(env, args[1], &cpu);

    /* Setup native-ts comm */
    napi_value resource_name = nullptr;
    napi_create_string_utf8(env, "native-ts comm", NAPI_AUTO_LENGTH, &resource_name);
    auto r = napi_create_threadsafe_function(env, args[2], nullptr, resource_name, 0, 1, nullptr, nullptr, nullptr, Callback, &g_log_callback);
    assert(r == napi_ok);
    
    /* Start tests in a child thread */
    if (t.joinable())
        t.join();
    t = std::thread([test_list, cpu] {
        test_states[TEST_GLOBAL].status = status_t::Initializing;
        do_log_update(TEST_GLOBAL);
        int rc = OH_QoS_SetThreadQoS(QoS_Level::QOS_USER_INTERACTIVE);

        if (rc != 0) {
            test_states[TEST_GLOBAL].status = status_t::Error;
            test_states[TEST_GLOBAL].message = "Set thread QoS failed";
            do_log_update(TEST_GLOBAL);
            return rc;
        }

        cpu_set_t mask;
        CPU_ZERO(&mask);
        CPU_SET(cpu, &mask);
        if (sched_setaffinity(0, sizeof(mask), &mask) != 0) {
            test_states[TEST_GLOBAL].status = status_t::Error;
            test_states[TEST_GLOBAL].message = "Set thread affinity failed";
            do_log_update(TEST_GLOBAL);
            return -1;
        }

        for (const auto test_no: test_list) {
            test_states[test_no].status = status_t::Initializing;
            do_log_update(test_no);
            
            if (test_cmdline.find(test_no) == test_cmdline.end()){
                test_states[test_no].status = status_t::Error;
                test_states[test_no].message = "cannot find cmdlist";
                do_log_update(test_no);
                continue;
            }
                
            if (chdir((std::string(SANDBOX_PATH) + '/' + test_names[test_no]).c_str()) != 0) {
                test_states[test_no].status = status_t::Error;
                test_states[test_no].message = "chdir failed";
                do_log_update(test_no);
                continue;
            }
                
            auto& cmds = test_cmdline[test_no];
            const char* libname = cmds[0][0];
            void* plib = dlopen(libname, RTLD_LAZY);
            if (plib == NULL) {
                test_states[test_no].status = status_t::Error;
                test_states[test_no].message = std::string("cannot open lib: ") + dlerror();
                do_log_update(test_no);
                continue;
            }
            
            specmain_t f_main = (specmain_t)dlsym(plib, "main");
            if (f_main == NULL) {
                test_states[test_no].status = status_t::Error;
                test_states[test_no].message = std::string("cannot get main func: ") + dlerror();
                do_log_update(test_no);
                continue;
            }
                
            dlclose(plib); // Will re-open it later when running
            
//             if (test_no == 500 || test_no == 502 || test_no == 531 || test_no == 557 || 
//                 test_no == 521 || test_no == 527) {
//                 __wrap = true;
//             } else {
//                 __wrap = false;
//             }
                
            test_states[test_no].status = status_t::Running;
            do_log_update(test_no);
    
            double time = 0;
            int ret = 0;
            for (int i = 0; i < cmds.size(); ++i) {
                test_states[test_no].status = status_t::Running;
                test_states[test_no].message = "[" + std::to_string(i + 1) + "/" + std::to_string(cmds.size()) + "]";
                do_log_update(test_no);
                
                plib = dlopen(libname, RTLD_NOW);
                f_main = (specmain_t)dlsym(plib, "main");
                specinit_t f_init = (specinit_t)dlsym(plib, "__init");
                specfinalize_t f_finalize = (specfinalize_t)dlsym(plib, "__freelist");
                const char** argv = cmds[i].data();
                
                // Init reference-counter
                if (f_init)
                    f_init();
                
                auto begin = std::chrono::steady_clock::now();
                ret = f_main(cmds[i].size(), argv);
                auto end = std::chrono::steady_clock::now();
                
                double laptime = std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count() / 1e6;
                time += laptime;
                
                // Free reference-counted memory
                if (f_finalize)
                    f_finalize();
                dlclose(plib); // detach lib to release memory leak in some tests (502?)
                
                if (ret != 0) {
                    test_states[test_no].status = status_t::Error;
                    test_states[test_no].message = "main func returned: " + std::to_string(ret);
                    do_log_update(test_no);
                    break;
                }
            }
            if (ret != 0) {
                continue;
            }
            
            test_states[test_no].status = status_t::Completed;
            test_states[test_no].time = time;
            do_log_update(test_no);
        }

        test_states[TEST_GLOBAL].status = status_t::Completed;
        do_log_update(TEST_GLOBAL);
        
        return 0;
    });

//     if (t.joinable())
//         t.join();

    napi_value ret;
    napi_create_double(env, 0, &ret);
    return ret;
}

// static napi_value RunTest(napi_env env, napi_callback_info info) {
//     napi_value ret;
//     napi_create_double(env, 0, &ret);
//     return ret;
// }

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr },
//         { "runTest", nullptr, RunTest, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "runTests", nullptr, RunTests, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "query", nullptr, Query, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void)
{
    napi_module_register(&demoModule);
}
