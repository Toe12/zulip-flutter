#!/bin/bash

# Every time a new AAB is uploaded to Google play, increase the version code in pubspec.yaml first!
# The keystore is at android/basecomms.jks and used from android/release-keystore.properties
# Using 'flutter run' will revert back to debug mode
# the jks and properties file are on OCI at ~/google-play-signing-keys

flutter build appbundle --release -Psigned
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
