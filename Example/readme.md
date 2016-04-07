```shell
brew install carthage

# Define earl grey by git tag in Cartfile.private
$ cat Cartfile.private
github "google/EarlGrey" "master"

# Create Cartfile.resolved 
carthage bootstrap --platform ios

# Update to latest revision
carthage update EarlGrey --platform ios

# Checkout deps as defined in Cartfile.resolved. 
# Fails if Cartfile.resolved doesn't exist
carthage checkout
```

Configure Objective-C Bridging Header:

`$(TARGET_NAME)/bridge.h`

Create EarlGrey.swift
Link EarlGrey.framework from Carthage/Build/iOS/EarlGrey.framework 

Framework Search Paths:
$(SRCROOT)/Carthage/Build/iOS

Header Search Paths (recursive):
$(SRCROOT)/Carthage/Build/iOS/**
