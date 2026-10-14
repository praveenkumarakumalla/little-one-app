"""Patch the Android project that `flutter create` generated: permissions, signing, min SDK, app name."""
import os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "android")

def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)
def must(cond, msg):
    if not cond:
        print("PREPARE FAILED:", msg); sys.exit(1)

# ---- keystore ----
shutil.copy(os.path.join(ROOT, "android_keystore", "release.jks"), os.path.join(A, "app", "release.jks"))

# ---- app/build.gradle(.kts) ----
kts = os.path.join(A, "app", "build.gradle.kts")
groovy = os.path.join(A, "app", "build.gradle")
if os.path.exists(kts):
    g = read(kts)
    g = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", g, count=1)
    must("minSdk = 24" in g, "minSdk not found in build.gradle.kts")
    sign = '''    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = "littleone2026"
            keyAlias = "littleone"
            keyPassword = "littleone2026"
        }
    }

    buildTypes {'''
    must("buildTypes {" in g, "buildTypes not found")
    g = g.replace("    buildTypes {", sign, 1)
    g = g.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    write(kts, g)
elif os.path.exists(groovy):
    g = read(groovy)
    g = re.sub(r"minSdk(Version)?\s*=?\s*[^\n]+", "minSdk = 24", g, count=1)
    sign = '''    signingConfigs {
        release {
            storeFile file("release.jks")
            storePassword "littleone2026"
            keyAlias "littleone"
            keyPassword "littleone2026"
        }
    }

    buildTypes {'''
    g = g.replace("    buildTypes {", sign, 1)
    g = g.replace("signingConfig = signingConfigs.debug", "signingConfig = signingConfigs.release").replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
    if "coreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
    write(groovy, g)
else:
    must(False, "no app/build.gradle found")

# ---- Kotlin plugin must be 2.0+ for the alarm plugin ----
for name in ("settings.gradle.kts", "settings.gradle"):
    p = os.path.join(A, name)
    if os.path.exists(p):
        s = read(p)
        m = re.search(r'org\.jetbrains\.kotlin\.android"\)?\s*version\s*"(\d+)\.(\d+)\.(\d+)"', s)
        if m and int(m.group(1)) < 2:
            s = s.replace(m.group(0), m.group(0).replace(f'{m.group(1)}.{m.group(2)}.{m.group(3)}', "2.1.0"))
            write(p, s)
        print("kotlin:", m.group(0) if m else "not found")

# ---- gradle.properties ----
gp = os.path.join(A, "gradle.properties")
s = read(gp)
for line in ("android.useAndroidX=true", "android.enableJetifier=true"):
    if line.split("=")[0] not in s: s += "\n" + line
write(gp, s + "\n")

# ---- AndroidManifest ----
mp = os.path.join(A, "app", "src", "main", "AndroidManifest.xml")
m = read(mp)
perms = ["INTERNET", "RECORD_AUDIO", "MODIFY_AUDIO_SETTINGS", "POST_NOTIFICATIONS", "VIBRATE", "WAKE_LOCK", "RECEIVE_BOOT_COMPLETED",
         "USE_FULL_SCREEN_INTENT", "FOREGROUND_SERVICE", "FOREGROUND_SERVICE_MEDIA_PLAYBACK", "FOREGROUND_SERVICE_MICROPHONE", "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS", "SCHEDULE_EXACT_ALARM", "USE_EXACT_ALARM",
         "ACCESS_NOTIFICATION_POLICY", "READ_MEDIA_AUDIO", "READ_MEDIA_IMAGES", "READ_MEDIA_VIDEO"]
block = "".join(f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in perms)
block += '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>\n'
must("<application" in m, "no <application> in manifest")
m = m.replace("    <application", block + "    <application", 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="Little One"', m, count=1)
q = '''        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
'''
if "<queries>" in m:
    m = m.replace("<queries>", "<queries>\n" + q, 1)
else:
    m = m.replace("</manifest>", "    <queries>\n" + q + "    </queries>\n</manifest>")
write(mp, m)

# ---- background listening service ----
svc = '        <service android:name=".ListenService" android:exported="false" android:stopWithTask="true" android:foregroundServiceType="microphone" />\n'
m = read(mp)
m = m.replace("    </application>", svc + "    </application>", 1)
must("ListenService" in m, "could not add ListenService to manifest")
write(mp, m)
act = None
for dp, _, fs in os.walk(os.path.join(A, "app", "src", "main")):
    for f in fs:
        if f in ("MainActivity.kt", "MainActivity.java"): act = os.path.join(dp, f)
must(act is not None, "MainActivity not found")
pkg = re.search(r"^package\s+([\w.]+)", read(act), re.M).group(1)
d = os.path.dirname(act)
if act.endswith(".java"): os.remove(act)
src = os.path.join(ROOT, "tool", "native")
for f in ("MainActivity.kt", "ListenService.kt"):
    write(os.path.join(d, f), read(os.path.join(src, f)).replace("__PKG__", pkg))
print("service added to", pkg)

# ---- remove the template test that refers to MyApp ----
t = os.path.join(ROOT, "test", "widget_test.dart")
if os.path.exists(t) and "MyApp" in read(t): os.remove(t)
print("prepare_android: done")
