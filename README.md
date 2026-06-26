# flutter-file-hash

```text
          /\_/\
       __( o.o )__
      /  /| # |\  \        WIP
     /__/ |___| \__\
          /   \
         /_____\        building hashes...

       Flutter + Zig core
```

`flutter-file-hash` is a work-in-progress Flutter package for hashing files and
bytes through a Zig-powered native core.

The repository is being bootstrapped. The public Dart API, platform packaging,
and release workflow are not stable yet.

## Planned Scope

- One shared Zig core via `zig-files-hash`
- Dart FFI bindings
- `fileHash` and `stringHash`
- Lowercase hex digest output
- Android, iOS, macOS, Linux, and Windows support
- Algorithms exposed by the `zig-files-hash` C ABI

## Status

Not ready for production use.

Current focus:

- wire the Zig C ABI into Flutter
- build native artifacts for all target platforms
- add cross-platform test vectors
- document the final Dart API

## Core

The hashing engine is pinned as a Git submodule:

```text
third_party/zig-files-hash
```

Initialize it after cloning:

```bash
git submodule update --init --recursive
```

## License

MIT
