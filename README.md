# Flutter for Embedded Linux (eLinux)
This software is a **non-official** extension to the [Flutter SDK](https://github.com/flutter/flutter) to build Flutter apps for Embedded Linux devices.

**The tool is still been developing! So, there is a lot of unsupported function.**

## Quick start
### How to insall flutter-elinux
```Shell
$ git clone https://github.com/sony/flutter-elinux.git
$ sudo mv flutter-elinux /opt/
$ export PATH=$PATH:/opt/flutter-elinux/bin
```

### How to run flutter sample app in Weston
```Shell
$ flutter-elinux create sample
$ cd sample
$ weston &
$ flutter-elinux run -d elinux
```

## Documentation
See https://github.com/sony/flutter-elinux/wiki

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md).

## Companion repos
| Repo | Purpose |
| ------------- | ------------- |
| [flutter-elinux](https://github.com/sony/flutter-elinux) | Flutter tools for eLinux |
| [flutter-elinux-plugins](https://github.com/sony/flutter-elinux-plugins) | Flutter plugins for eLinux |
| [flutter-embedded-linux](https://github.com/sony/flutter-embedded-linux) | eLinux embedding for Flutter |
| [meta-flutter](https://github.com/sony/meta-flutter) | Yocto recipes of eLinux embedding for Flutter |

## Base software
This software was created based on the [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) (branched from [this version](https://github.com/flutter-tizen/flutter-tizen/commit/ed128233c0bce33c77dd0df69afa59f0888d2d00)). Special thanks to the flutter-tizen team.
