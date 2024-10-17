# Readme

## linux
### dbus
dbus 由 dbus-code生成，详情可查看`https://github.com/diwic/dbus-rs?tab=readme-ov-file`。
```shell
dbus-codegen-rust -c nonblock -d org.kde.plasmashell -p /PlasmaShell > wallpaper.rs
```