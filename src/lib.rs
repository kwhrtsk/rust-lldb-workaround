#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        // With cargo 1.41.0, breakpoint does not work on next line.
        // https://github.com/rust-lang/rust/issues/59907
        assert_eq!(2 + 2, 4);
    }
}
