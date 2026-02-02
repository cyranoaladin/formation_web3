#![no_std]

#[cfg(feature = "std")]
extern crate std;

#[derive(Debug, Clone, Copy)]
pub struct Error;

impl Error {
    pub fn raw_os_error(&self) -> Option<i32> {
        None
    }
}

#[cfg(feature = "std")]
impl std::error::Error for Error {}

#[cfg(feature = "std")]
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "getrandom error")
    }
}

pub type Result<T> = core::result::Result<T, Error>;

pub fn getrandom(dest: &mut [u8]) -> Result<()> {
    for b in dest.iter_mut() {
        *b = 0;
    }
    Ok(())
}

pub fn fill(dest: &mut [u8]) -> Result<()> {
    getrandom(dest)
}
