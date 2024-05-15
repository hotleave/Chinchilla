# Chinchilla
A input method for macOS based on Swift and CMake,
forked from [eagleoflqj/toyimk](https://github.com/eagleoflqj/toyimk):
A project is for developers who don't like deprecated Objective-C and ugly `.xcodeproj`.

## Install dependencies
```sh
brew install swiftlint ninja
pip install "dmgbuild[badge_icons]"
```

```sh
# download and build librime on the parent folder: https://github.com/rime/librime/blob/master/README-mac.md
# use `make install` to generate the dist folder
```

## Build
```sh
cmake -B build -G Ninja \
  -DARCH=[native|x86_64|arm64] \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## Install
Either open `build/Chinchilla.dmg`
(if prompted Chinchilla is in use error,
execute `pkill Chinchilla` and retry), or
```sh
# Install to ~/Library/Input Methods
cmake --install build
```
* On first time installation,
logout your account and login,
then in `System Settings` -> `Keyboard` -> `Input Sources`,
add `Chinchilla` from `Chinese`.
* On further installations,
switch to another input method,
`pkill Chinchilla`,
then switch back.
* You may change what is committed at `client.insert` in [controller.swift](src/controller.swift) to make sure your changes take effect.

## Debug
Yes, though being a system module, input method is debuggable.
However, you need another machine to do it.
```sh
$ ssh your-mac
$ /usr/bin/lldb
(lldb) process attach --name Chinchilla
(lldb) b inputText
(lldb) c
```
Now switch to Chinchilla and hit a key.
