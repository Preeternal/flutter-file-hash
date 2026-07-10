# Benchmarks

These numbers are manual smoke benchmarks from the bundled example app. Treat
them as rough device-local reference points, not as a stable cross-device
performance contract.

The example's benchmark JSON includes `useMmap`; record it with each run. mmap
is disabled by default and should be compared only on stable local files.

## mmap observations

Local mmap measurements varied by workload. In 200 MiB Flutter release
comparisons, results ranged from mixed low-single-digit changes to all recorded
medians being roughly 2-11% faster. Separate direct Zig-core measurements on a
500 MiB file showed up to roughly 20% improvement for some algorithms.

mmap remains disabled by default; benchmark the target device, file size,
storage, and algorithm before enabling it.

## Apple A15, iOS Release, 2026-06-30

- Device: physical Apple A15 device
- Build: example app, iOS release build
- Input: generated benchmark file from the example app
- Size: 200 MiB
- Samples: 3
- Warmups: 1
- Reported by: project maintainer

| Algorithm | Median | Min | Max | Digest prefix |
| --- | ---: | ---: | ---: | --- |
| SHA-256 | 118 ms | 118 ms | 118 ms | `bf375859eeb4cfaf` |
| MD5 | 346 ms | 346 ms | 347 ms | `b01c09f68fe1a4f6` |
| SHA-1 | 276 ms | 276 ms | 276 ms | `5934b5f0e888d4c2` |
| SHA-224 | 117 ms | 117 ms | 123 ms | `7114fb0a4a804e77` |
| SHA-384 | 557 ms | 556 ms | 570 ms | `6a568d918e476792` |
| SHA-512 | 571 ms | 570 ms | 571 ms | `4a6e943a3a26ec5e` |
| SHA-512/224 | 569 ms | 562 ms | 602 ms | `d710923101e26ef1` |
| SHA-512/256 | 587 ms | 587 ms | 587 ms | `da10d3c664eb429d` |
| HMAC-SHA-224 | 117 ms | 117 ms | 118 ms | `2bd56fe612a66412` |
| HMAC-SHA-256 | 117 ms | 117 ms | 118 ms | `b0504e25665ecced` |
| HMAC-SHA-384 | 588 ms | 586 ms | 589 ms | `afc522ea95da42fe` |
| HMAC-SHA-512 | 594 ms | 593 ms | 595 ms | `9ccb30acba435827` |
| HMAC-MD5 | 346 ms | 346 ms | 346 ms | `308a9d537f57e68e` |
| HMAC-SHA-1 | 284 ms | 280 ms | 285 ms | `b8044c774b172ca9` |
| BLAKE3 | 162 ms | 160 ms | 164 ms | `7f4335c908146450` |
| XXH3-64 | 28.0 ms | 26.0 ms | 28.0 ms | `0bcfd32743ab9251` |

## Apple Silicon, macOS Release, 2026-06-30

- Device: physical Apple Silicon macOS device
- Build: example app, macOS release build
- Input: generated benchmark file from the example app
- Size: 200 MiB
- Samples: 3
- Warmups: 1
- Reported by: project maintainer

| Algorithm | Median | Min | Max | Digest prefix |
| --- | ---: | ---: | ---: | --- |
| SHA-256 | 79.0 ms | 79.0 ms | 79.0 ms | `bf375859eeb4cfaf` |
| MD5 | 241 ms | 241 ms | 241 ms | `b01c09f68fe1a4f6` |
| SHA-1 | 168 ms | 167 ms | 168 ms | `5934b5f0e888d4c2` |
| SHA-224 | 78.0 ms | 78.0 ms | 78.0 ms | `7114fb0a4a804e77` |
| SHA-384 | 286 ms | 286 ms | 288 ms | `6a568d918e476792` |
| SHA-512 | 288 ms | 287 ms | 291 ms | `4a6e943a3a26ec5e` |
| SHA-512/224 | 289 ms | 285 ms | 289 ms | `d710923101e26ef1` |
| SHA-512/256 | 289 ms | 287 ms | 290 ms | `da10d3c664eb429d` |
| HMAC-SHA-224 | 78.0 ms | 78.0 ms | 78.0 ms | `2bd56fe612a66412` |
| HMAC-SHA-256 | 78.0 ms | 78.0 ms | 78.0 ms | `b0504e25665ecced` |
| HMAC-SHA-384 | 287 ms | 287 ms | 291 ms | `afc522ea95da42fe` |
| HMAC-SHA-512 | 290 ms | 288 ms | 294 ms | `9ccb30acba435827` |
| HMAC-MD5 | 240 ms | 240 ms | 241 ms | `308a9d537f57e68e` |
| HMAC-SHA-1 | 167 ms | 167 ms | 168 ms | `b8044c774b172ca9` |
| BLAKE3 | 103 ms | 102 ms | 103 ms | `7f4335c908146450` |
| XXH3-64 | 14.0 ms | 14.0 ms | 14.0 ms | `0bcfd32743ab9251` |

## Android ARM64, Android Release, 2026-06-30

- Device: physical ARM64 Android device, Android 16
- Build: example app, Android release build
- Input: generated benchmark file from the example app
- Size: 200 MiB
- Samples: 3
- Warmups: 1
- Reported by: project maintainer

| Algorithm | Median | Min | Max | Digest prefix |
| --- | ---: | ---: | ---: | --- |
| SHA-256 | 1149 ms | 1134 ms | 1157 ms | `bf375859eeb4cfaf` |
| MD5 | 562 ms | 550 ms | 564 ms | `b01c09f68fe1a4f6` |
| SHA-1 | 527 ms | 525 ms | 533 ms | `5934b5f0e888d4c2` |
| SHA-224 | 1160 ms | 1150 ms | 1168 ms | `7114fb0a4a804e77` |
| SHA-384 | 764 ms | 761 ms | 765 ms | `6a568d918e476792` |
| SHA-512 | 764 ms | 759 ms | 764 ms | `4a6e943a3a26ec5e` |
| SHA-512/224 | 761 ms | 759 ms | 762 ms | `d710923101e26ef1` |
| SHA-512/256 | 766 ms | 765 ms | 789 ms | `da10d3c664eb429d` |
| HMAC-SHA-224 | 1165 ms | 1153 ms | 1172 ms | `2bd56fe612a66412` |
| HMAC-SHA-256 | 1154 ms | 1153 ms | 1166 ms | `b0504e25665ecced` |
| HMAC-SHA-384 | 763 ms | 763 ms | 765 ms | `afc522ea95da42fe` |
| HMAC-SHA-512 | 767 ms | 760 ms | 773 ms | `9ccb30acba435827` |
| HMAC-MD5 | 551 ms | 551 ms | 562 ms | `308a9d537f57e68e` |
| HMAC-SHA-1 | 523 ms | 520 ms | 527 ms | `b8044c774b172ca9` |
| BLAKE3 | 351 ms | 349 ms | 351 ms | `7f4335c908146450` |
| XXH3-64 | 70.0 ms | 70.0 ms | 75.0 ms | `0bcfd32743ab9251` |

## Intel Core i3-7100U, Linux Release, 2026-07-01

- Device: physical Linux x64 laptop, Ubuntu 24.04.4 LTS, 24 GiB RAM
- Build: example app, Linux release build
- Input: generated benchmark file from the example app
- Size: 200 MiB
- Samples: 3
- Warmups: 1
- Reported by: project maintainer

| Algorithm | Median | Min | Max | Digest prefix |
| --- | ---: | ---: | ---: | --- |
| SHA-256 | 2122 ms | 2112 ms | 2200 ms | `bf375859eeb4cfaf` |
| MD5 | 629 ms | 628 ms | 646 ms | `b01c09f68fe1a4f6` |
| SHA-1 | 987 ms | 981 ms | 1025 ms | `5934b5f0e888d4c2` |
| SHA-224 | 2496 ms | 2410 ms | 2701 ms | `7114fb0a4a804e77` |
| SHA-384 | 1485 ms | 1451 ms | 1543 ms | `6a568d918e476792` |
| SHA-512 | 1463 ms | 1454 ms | 1526 ms | `4a6e943a3a26ec5e` |
| SHA-512/224 | 1438 ms | 1421 ms | 1464 ms | `d710923101e26ef1` |
| SHA-512/256 | 1472 ms | 1443 ms | 1494 ms | `da10d3c664eb429d` |
| HMAC-SHA-224 | 2454 ms | 2229 ms | 2824 ms | `2bd56fe612a66412` |
| HMAC-SHA-256 | 2233 ms | 2155 ms | 2285 ms | `b0504e25665ecced` |
| HMAC-SHA-384 | 1488 ms | 1485 ms | 1548 ms | `afc522ea95da42fe` |
| HMAC-SHA-512 | 1531 ms | 1459 ms | 1617 ms | `9ccb30acba435827` |
| HMAC-MD5 | 651 ms | 639 ms | 654 ms | `308a9d537f57e68e` |
| HMAC-SHA-1 | 1073 ms | 1053 ms | 1160 ms | `b8044c774b172ca9` |
| BLAKE3 | 388 ms | 364 ms | 392 ms | `7f4335c908146450` |
| XXH3-64 | 67.0 ms | 67.0 ms | 105 ms | `0bcfd32743ab9251` |

## Windows ARM64 VM, Windows Release, 2026-06-30

- Device: QEMU 10.0 ARM Virtual Machine, ARM64, 8 GB RAM
- Build: example app, Windows release build
- Input: generated benchmark file from the example app
- Size: 200 MiB
- Samples: 3
- Warmups: 1
- Reported by: project maintainer

| Algorithm | Median | Min | Max | Digest prefix |
| --- | ---: | ---: | ---: | --- |
| SHA-256 | 534 ms | 527 ms | 535 ms | `bf375859eeb4cfaf` |
| MD5 | 298 ms | 292 ms | 305 ms | `b01c09f68fe1a4f6` |
| SHA-1 | 209 ms | 209 ms | 225 ms | `5934b5f0e888d4c2` |
| SHA-224 | 532 ms | 529 ms | 533 ms | `7114fb0a4a804e77` |
| SHA-384 | 363 ms | 347 ms | 364 ms | `6a568d918e476792` |
| SHA-512 | 357 ms | 353 ms | 358 ms | `4a6e943a3a26ec5e` |
| SHA-512/224 | 354 ms | 349 ms | 364 ms | `d710923101e26ef1` |
| SHA-512/256 | 346 ms | 344 ms | 375 ms | `da10d3c664eb429d` |
| HMAC-SHA-224 | 544 ms | 541 ms | 546 ms | `2bd56fe612a66412` |
| HMAC-SHA-256 | 549 ms | 542 ms | 550 ms | `b0504e25665ecced` |
| HMAC-SHA-384 | 368 ms | 360 ms | 385 ms | `afc522ea95da42fe` |
| HMAC-SHA-512 | 365 ms | 360 ms | 376 ms | `9ccb30acba435827` |
| HMAC-MD5 | 313 ms | 307 ms | 316 ms | `308a9d537f57e68e` |
| HMAC-SHA-1 | 230 ms | 223 ms | 245 ms | `b8044c774b172ca9` |
| BLAKE3 | 143 ms | 139 ms | 150 ms | `7f4335c908146450` |
| XXH3-64 | 47.0 ms | 47.0 ms | 48.0 ms | `0bcfd32743ab9251` |
