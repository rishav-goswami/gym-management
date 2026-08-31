# App-specific R8 rules for production Android builds.
#
# Flutter and Firebase Android libraries publish their own consumer rules. Keep
# additions here narrow: broad `-keep` rules would defeat shrinking and code
# obfuscation. Preserve line information for Crashlytics while hiding original
# source file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
