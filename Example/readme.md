```shell
brew install carthage

# Define earl grey by git tag in Cartfile.private
$ cat Cartfile.private
github "google/EarlGrey" ~> 1.0.0

# Create Cartfile.resolved 
carthage bootstrap --no-build --no-use-binaries

# Checkout deps as defined in Cartfile.resolved. 
# Fails if Cartfile.resolved doesn't exist
carthage checkout --no-use-binaries

# Run EarlGrey setup script
cd Carthage/Checkouts/EarlGrey
./Scripts/setup-earlgrey.sh
cd -
```
