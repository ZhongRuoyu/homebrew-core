class Bear < Formula
  desc "Generate compilation database for clang tooling"
  homepage "https://github.com/rizsotto/Bear"
  url "https://github.com/rizsotto/Bear/archive/refs/tags/3.1.6.tar.gz"
  sha256 "99cd891eec6e89b734d7cafe0e623dd8c2f27d8cbf3ee9bc4807e69e5c8fb55c"
  license "GPL-3.0-or-later"
  revision 4
  head "https://github.com/rizsotto/Bear.git", branch: "master"

  bottle do
    sha256 arm64_sequoia: "1c0ceb4233e0aa4578073c4eb04268afdc164e0e3a6127705527c081b00ce3dd"
    sha256 arm64_sonoma:  "222df9811285516c4f015944a0f29c797df19e080c76e389cd5b289664a3ec5c"
    sha256 arm64_ventura: "46aa32de116bae6251bb6cdaddff15e50499d7601abd50a789c82566397b4a7e"
    sha256 sonoma:        "3c4cede65ed4fa8c0794be647c0118cb0ea13989c1eacbbe40fb06c98f5cb9c4"
    sha256 ventura:       "80575de010582294946271bc3b05ff3925d9c3d426f97c4e040fc18c176c9112"
    sha256 arm64_linux:   "1754da1c6321bec303deabb024f1302fda5cd3375ed275de615f317664c6f68d"
    sha256 x86_64_linux:  "1c97a6cc692bb2a177a84ff460362e8df1d1036ab0d5006cedf57a82d1565828"
  end

  depends_on "cmake" => :build
  depends_on "pkgconf" => :build
  depends_on "abseil"
  depends_on "fmt"
  depends_on "grpc"
  depends_on "nlohmann-json"
  depends_on "protobuf"
  depends_on "spdlog"

  on_macos do
    depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  end

  fails_with :clang do
    build 1100
    cause <<~EOS
      Undefined symbols for architecture x86_64:
        "std::__1::__fs::filesystem::__current_path(std::__1::error_code*)"
    EOS
  end

  def file_prepend(filename, contents)
    path = Pathname(filename)
    old_contents = path.read
    path.atomic_write <<~EOS
      #{contents}
      #{old_contents}
    EOS
  end

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)

    if OS.linux?
      [
        "source/intercept/source/report/libexec/Linker.cc",
        "source/libsys/source/Process.cc",
      ].each do |file|
        file_prepend file, <<~EOS
          __asm__(".symver dlsym, dlsym@GLIBC_2.2.5");
        EOS
      end

      file_prepend "source/intercept/source/report/libexec/Resolver.cc", <<~EOS
        extern "C" {
          __asm__(".symver __xstat, __xstat@@@GLIBC_2.2.5");
          int __xstat(int __ver, const char *__filename,
                      struct stat *__stat_buf);

          static int stat(const char *__filename, struct stat *__stat_buf) {
            // https://github.com/bminor/glibc/blob/glibc-2.35/sysdeps/unix/sysv/linux/x86/xstatver.h
            return __xstat(1, __filename, __stat_buf);
          }
        }
      EOS

      ENV.append "LDFLAGS", "-static-libstdc++ -static-libgcc"
    end

    args = %w[
      -DENABLE_UNIT_TESTS=OFF
      -DENABLE_FUNC_TESTS=OFF
    ]
    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    if OS.linux?
      # `dlsym` has been integrated into libc in glibc 2.34, so libdl is not
      # linked anymore. To allow it to be used on older systems, we need to make
      # sure libdl is added as a dependency. This does not affect systems with
      # glibc 2.34 or newer, because libdl is kept as an empty library.
      patcher = (lib/"bear/libexec.so").patchelf_patcher
      patcher.add_needed "libdl.so.2"
      patcher.save
    end
  end

  test do
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      int main() {
        printf("hello, world!\\n");
        return 0;
      }
    C
    system bin/"bear", "--", ENV.cc, "test.c"
    assert_path_exists testpath/"compile_commands.json"
  end
end
