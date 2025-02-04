{ name, version }:
{

  ".cargo/config.toml" = ''
    [target.'cfg(all(target_arch = "arm", target_os = "none"))']
    # runner = "probe-rs run --chip RP2040 --protocol swd"
    runner = "elf2uf2-rs -d"

    rustflags = [
      "-C", "linker=flip-link",

      "-C", "link-arg=--nmagic",
      "-C", "link-arg=-Tlink.x",
      "-C", "link-arg=-Tlink-rp.x",
      "-C", "link-arg=-Tdefmt.x",

      "-C", "no-vectorize-loops",
      "-Z", "trap-unreachable=no",
    ]

    [build]
    target = "thumbv6m-none-eabi" # Cortex-M0 and Cortex-M0+

    [env]
    DEFMT_LOG = "debug"
  '';

  "build.rs" = ''
    //! This build script copies the `memory.x` file from the crate root into
    //! a directory where the linker can always find it at build time.
    //! For many projects this is optional, as the linker always searches the
    //! project root directory -- wherever `Cargo.toml` is. However, if you
    //! are using a workspace or have a more complicated build setup, this
    //! build script becomes required. Additionally, by requesting that
    //! Cargo re-run the build script whenever `memory.x` is changed,
    //! updating `memory.x` ensures a rebuild of the application with the
    //! new memory settings.

    use std::env;
    use std::fs::File;
    use std::io::Write;
    use std::path::PathBuf;

    fn main() {
        // Put `memory.x` in our output directory and ensure it's
        // on the linker search path.
        let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
        File::create(out.join("memory.x"))
            .unwrap()
            .write_all(include_bytes!("memory.x"))
            .unwrap();
        println!("cargo:rustc-link-search={}", out.display());

        // By default, Cargo will re-run a build script whenever
        // any file in the project changes. By specifying `memory.x`
        // here, we ensure the build script is only re-run when
        // `memory.x` is changed.
        println!("cargo:rerun-if-changed=memory.x");

        /*
        println!("cargo:rustc-link-arg-bins=--nmagic");
        println!("cargo:rustc-link-arg-bins=-Tlink.x");
        println!("cargo:rustc-link-arg-bins=-Tlink-rp.x");
        println!("cargo:rustc-link-arg-bins=-Tdefmt.x");
        */
    }
  '';

  "Cargo.toml" = ''
    [package]
    name = "${name}"
    version = "${version}"
    edition = "2024"

    [dependencies]
    cortex-m-rt = { version = "*" }
    defmt = { version = "*" }
    defmt-rtt = { version = "*" }
    embassy-executor = { version = "*", features = [ "arch-cortex-m", "defmt", "executor-thread", "executor-interrupt", "task-arena-size-98304" ] }
    embassy-rp = { version = "*", features = [ "defmt", "unstable-pac", "time-driver", "critical-section-impl", "rp2040" ] }
    embassy-time = { version = "*", features = [ "defmt", "defmt-timestamp-uptime" ] }
    panic-probe = { version = "*", features = [ "print-defmt" ] }

    [profile.dev]
    debug = 2
    lto = true
    opt-level = "z"

    [profile.release]
    debug = 2
    lto = true
    opt-level = "z"
  '';

  "Cargo.lock" = ''
    version = 4

    package = []
  '';

  "memory.x" = ''
    MEMORY {
        BOOT2 : ORIGIN = 0x10000000, LENGTH = 0x100
        FLASH : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100

        /* Pick one of the two options for RAM layout     */

        /* OPTION A: Use all RAM banks as one big block   */
        /* Reasonable, unless you are doing something     */
        /* really particular with DMA or other concurrent */
        /* access that would benefit from striping        */
        /* RAM   : ORIGIN = 0x20000000, LENGTH = 264K     */

        /* OPTION B: Keep the unstriped sections separate */
        RAM: ORIGIN = 0x20000000, LENGTH = 256K
        SCRATCH_A: ORIGIN = 0x20040000, LENGTH = 4K
        SCRATCH_B: ORIGIN = 0x20041000, LENGTH = 4K
    }

    EXTERN(BOOT2_FIRMWARE)

    SECTIONS {
        /* ### Boot loader */
        .boot2 ORIGIN(BOOT2) :
        {
            KEEP(*(.boot2));
        } > BOOT2
    } INSERT BEFORE .text;
  '';

  "rust-toolchain.toml" = ''
    [toolchain]
    channel = "nightly"
    targets = [ "thumbv6m-none-eabi" ]
  '';

}
