#!/bin/bash

rm -rf target
bin=$(cargo test --lib --no-run --message-format=json | jq -r '.executable')

# create symlink of .dSYM directory
(cd target/debug && for d in deps/*.dSYM; do ln -sf $d ./; done)

rust-lldb $bin <<- EOF
breakpoint set --name tests::it_works
EOF
