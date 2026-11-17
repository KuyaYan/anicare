#!/usr/bin/env python3
"""Run by setup_and_build.sh after `flutter create`. Patches the generated android/ folder:
   - app name, INTERNET + POST_NOTIFICATIONS permissions, back-button callback (AndroidManifest.xml)
   - core library desugaring (needed by flutter_local_notifications) in android/app/build.gradle(.kts)
It is safe to run more than once."""
import pathlib, re, sys

man = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = man.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="AniCare"', s, count=1)
for perm in ('android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS'):
    if perm not in s:
        s = s.replace('<application', f'<uses-permission android:name="{perm}"/>\n    <application', 1)
# Android 13+ back-button support (enableOnBackInvokedCallback).
    # The app uses PopScope which works on all API levels; keep this only when the
    # generated manifest already contains it (targetSdk >= 33) to avoid build errors
    # on lower minSdkVersion projects.
    if 'enableOnBackInvokedCallback' not in s:
        # only add if the manifest already declares a targetSdk that supports it;
        # safer to skip so the build does not fail on minSdk < 33.
        pass  # do not add enableOnBackInvokedCallback unconditionally
man.write_text(s)
print('manifest patched:', man)

kts = pathlib.Path('android/app/build.gradle.kts')
groovy = pathlib.Path('android/app/build.gradle')
if kts.exists():
    g = kts.read_text()
    if 'isCoreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        if n == 0:
            sys.exit('Could not find compileOptions in build.gradle.kts - see supabase-and-maya-guide.md (Android build error)')
    if 'coreLibraryDesugaring(' not in g:
        line = '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        if re.search(r'^dependencies\s*\{', g, re.M):
            g = re.sub(r'^(dependencies\s*\{)', r'\1\n' + line, g, count=1, flags=re.M)
        else:
            g += '\ndependencies {\n' + line + '\n}\n'
    kts.write_text(g)
    print('gradle (kts) patched')
elif groovy.exists():
    g = groovy.read_text()
    if 'coreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', g, count=1)
        if n == 0:
            sys.exit('Could not find compileOptions in build.gradle - see supabase-and-maya-guide.md (Android build error)')
    if 'coreLibraryDesugaring ' not in g:
        line = "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        if re.search(r'^dependencies\s*\{', g, re.M):
            g = re.sub(r'^(dependencies\s*\{)', r'\1\n' + line, g, count=1, flags=re.M)
        else:
            g += '\ndependencies {\n' + line + '\n}\n'
    groovy.write_text(g)
    print('gradle (groovy) patched')
else:
    sys.exit('No android/app/build.gradle(.kts) found')
