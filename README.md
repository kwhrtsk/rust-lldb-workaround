rust-lldb problem with unit tests in a lib target.
==================================================

**[UPDATE]**

This problem has already been fixed on master([rust-lang/cargo#7965][3]),
and will be released as [Cargo 1.43][4] at 2020-04-03.

## Problem description

On macOS, when I build tests in a lib target (with cargo test --lib --no-run),
and run LLDB on the test binary, breakpoints does not work.

This problem occurs with both `rust-lldb` and VSCode with [CodeLLDB][1].

## Environment

* **Operating system:** macOS Catalina 10.15.3
* **Rust toolchain:** stable-x86_64-apple-darwin
* **Rustc version:** 1.41.1 (f3e1a954d 2020-02-24)
* **lldb:** 9.0.1
* **VSCode:** 1.42.1
* **CodeLLDB:** 1.5.0

## Steps to reproduce

* `Cargo.toml`

```toml
[package]
name = "rust-lldb-workaround"
version = "0.1.0"
edition = "2018"
```

* `src/lib.rs`

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
```

* `test.sh` (script to reproduce)

```
#!/bin/bash

rm -rf target
bin=$(cargo test --lib --no-run --message-format=json | jq -r '.executable')
rust-lldb $bin <<- EOF
breakpoint set --name tests::it_works
EOF
```

```
   Compiling rust-lldb-workaround v0.1.0 (/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround)
    Finished test [unoptimized + debuginfo] target(s) in 0.51s
(lldb) command script import "/Users/kawahara_taisuke/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/etc/lldb_rust_formatters.py"
(lldb) type summary add --no-value --python-function lldb_rust_formatters.print_val -x ".*" --category Rust
(lldb) type category enable Rust
(lldb) target create "/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-6e0ca18365abb7b9"
Current executable set to '/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-6e0ca18365abb7b9' (x86_64).
(lldb) breakpoint set --name tests::it_works
Breakpoint 1: no locations (pending).
WARNING:  Unable to resolve breakpoint to any actual locations.
```

## Why breakpoint does not work?

When build tests in a bin target, `cargo test` will create `.dSYM` in `target/debug/` directory.

```
% cargo test --bins --no-run --message-format=json 2> /dev/null | jq 'select(.target.kind | contains(["bin"])) | .filenames'
[
  "/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-4aae58342b9c3866",
  "/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-4aae58342b9c3866.dSYM"
]

% ls -l target/debug
total 1720
drwxr-xr-x  2 kawahara_taisuke  staff      64  3  3 13:47 build
drwxr-xr-x  8 kawahara_taisuke  staff     256  3  3 13:47 deps
drwxr-xr-x  2 kawahara_taisuke  staff      64  3  3 13:47 examples
drwxr-xr-x  4 kawahara_taisuke  staff     128  3  3 13:47 incremental
-rwxr-xr-x  2 kawahara_taisuke  staff  874952  3  3 13:47 rust_lldb_workaround-4aae58342b9c3866
-rw-r--r--  1 kawahara_taisuke  staff     282  3  3 13:47 rust_lldb_workaround-4aae58342b9c3866.d
lrwxr-xr-x  1 kawahara_taisuke  staff      47  3  3 13:47 rust_lldb_workaround-4aae58342b9c3866.dSYM -> deps/rust_lldb_workaround-4aae58342b9c3866.dSYM
```

But not when build tests in a lib target.

```
% cargo test --lib --no-run --message-format=json 2> /dev/null | jq 'select(.target.kind | contains(["lib"])) | .filenames'
[
  "/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-6e0ca18365abb7b9"
]

% ls -l target/debug
total 1720
drwxr-xr-x  2 kawahara_taisuke  staff      64  3  3 13:49 build
drwxr-xr-x  5 kawahara_taisuke  staff     160  3  3 13:49 deps
drwxr-xr-x  2 kawahara_taisuke  staff      64  3  3 13:49 examples
drwxr-xr-x  3 kawahara_taisuke  staff      96  3  3 13:49 incremental
-rwxr-xr-x  2 kawahara_taisuke  staff  874968  3  3 13:49 rust_lldb_workaround-6e0ca18365abb7b9
-rw-r--r--  1 kawahara_taisuke  staff     201  3  3 13:49 rust_lldb_workaround-6e0ca18365abb7b9.d

% ls -l target/debug/deps
total 1720
-rwxr-xr-x  2 kawahara_taisuke  staff  874968  3  3 13:49 rust_lldb_workaround-6e0ca18365abb7b9
-rw-r--r--  1 kawahara_taisuke  staff     290  3  3 13:49 rust_lldb_workaround-6e0ca18365abb7b9.d
drwxr-xr-x  3 kawahara_taisuke  staff      96  3  3 13:49 rust_lldb_workaround-6e0ca18365abb7b9.dSYM
```

It seems to be intentional at the moment, and the binaries under `deps` directories are expected to run.

https://github.com/rust-lang/cargo/blob/e618d47a1765ca18d1601d4cf891a55a34d23aed/src/cargo/core/compiler/build_context/target_info.rs#L260-L269

But for tools like [CodeLLDB][1], it is desirable to create a `.dSYM` in `target/debug/` (at least at the moment).

In this document shows a simple workaround that just create `.dSYM` symlink in `target/debug/`.
Please let me know if you have any unexpected side effects.

## Workaround

Manually create a symlink to `.dSYM` between `cargo test` and `llvm`.

* test-workaround.sh

```
#!/bin/bash

rm -rf target
bin=$(cargo test --lib --no-run --message-format=json | jq -r '.executable')

# create symlink of .dSYM directory
(cd target/debug && for d in deps/*.dSYM; do ln -sf $d ./; done)

rust-lldb $bin <<- EOF
breakpoint set --name tests::it_works
EOF
```

```
   Compiling rust-lldb-workaround v0.1.0 (/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround)
    Finished test [unoptimized + debuginfo] target(s) in 0.53s
(lldb) command script import "/Users/kawahara_taisuke/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/etc/lldb_rust_formatters.py"
(lldb) type summary add --no-value --python-function lldb_rust_formatters.print_val -x ".*" --category Rust
(lldb) type category enable Rust
(lldb) target create "/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-6e0ca18365abb7b9"
Current executable set to '/Users/kawahara_taisuke/.ghq/github.com/kwhrtsk/rust-lldb-workaround/target/debug/rust_lldb_workaround-6e0ca18365abb7b9' (x86_64).
(lldb) breakpoint set --name tests::it_works
Breakpoint 1: where = rust_lldb_workaround-6e0ca18365abb7b9`rust_lldb_workaround::tests::it_works::h666f078a6b384dfd + 18 at lib.rs:7:8, address = 0x0000000100000cd2
```

### VSCode

If you try to do the same with VSCode (and CodeLLDB), you get:

* `.vscode/launch.json`

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "lldb",
      "request": "launch",
      "name": "Debug unit tests in library 'rust-lldb-workaround'",
      "cargo": {
        "args": [
          "test",
          "--no-run",
          "--lib",
          "--package=rust-lldb-workaround"
        ],
        "filter": {
          "name": "rust-lldb-workaround",
          "kind": "lib"
        }
      },
      "args": [],
      "cwd": "${workspaceFolder}",
      // Add this line.
      "preLaunchTask": "symlink dSYM"
    }
  ]
}
```

* `.vscode/tasks.json`

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "symlink dSYM",
      "type": "shell",
      "command": "sh",
      "args": [
        "-c",
        "cd ${workspaceFolder}/target/debug; for d in deps/*.dSYM; do ln -fs $d ./; done"
      ]
    }
  ]
}
```

## References

* [rust-lang/rust#59907](https://github.com/rust-lang/rust/issues/59907)
* [rust-lang/cargo#7960](https://github.com/rust-lang/cargo/issues/7960)

If you are looking for Japanese translation, please see [this blog post][2].

[1]: https://github.com/vadimcn/vscode-lldb
[2]: https://chopschips.net/blog/2020/03/03/rust-lldb-workaround/
[3]: https://github.com/rust-lang/cargo/pull/7965
[4]: https://github.com/rust-lang/cargo/blob/master/CHANGELOG.md#cargo-143-2020-04-23
