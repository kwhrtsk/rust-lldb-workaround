#!/bin/bash

rm -rf target
bin=$(cargo test --lib --no-run --message-format=json | jq -r '.executable')
rust-lldb $bin <<- EOF
breakpoint set --name tests::it_works
EOF
