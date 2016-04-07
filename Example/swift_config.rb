require 'rubygems'
require 'xcodeproj'
require 'colored'
require_relative 'configure_earlgrey_pods.rb'

# xcodebuild -list # lists project/targets/scheme
PROJECT_NAME      = 'Example'
TEST_TARGET_SWIFT = 'ExampleEarlGrey'
SCHEME_FILE_SWIFT = 'ExampleEarlGrey.xcscheme'

configure_for_earlgrey(PROJECT_NAME, TEST_TARGET_SWIFT, SCHEME_FILE_SWIFT)
