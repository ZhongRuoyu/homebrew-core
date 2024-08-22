class P4c < Formula
  desc "Reference compiler for the P4 programming language"
  homepage "https://p4.org/"
  url "https://github.com/p4lang/p4c/archive/refs/tags/v1.2.4.14.tar.gz"
  sha256 "5e4170868a2b73453bc54dd776a522870f540f64ad7864a0a24fbec57e3f4dc7"
  license "Apache-2.0"
  head "https://github.com/p4lang/p4c.git", branch: "main"

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "flex" => :build
  depends_on "abseil"
  depends_on "bdw-gc"
  depends_on "boost"
  depends_on "protobuf"

  uses_from_macos "python"

  on_linux do
    depends_on "libbpf"
  end

  # Use the GIT_TAG in https://github.com/p4lang/p4c/blob/v#{version}/CMakeLists.txt#L423
  resource "p4runtime" do
    url "https://github.com/p4lang/p4runtime/archive/62a9bd60599b87497a15feb6c7893b7ec8ba461f.tar.gz"
    sha256 "13615c31821f6d3a8f11d186a13d8c41bb988c8eccd7b24c0552f4465861b93b"
  end

  def install
    resource("p4runtime").stage buildpath/"p4runtime"

    ENV.append_to_cflags "-I#{Formula["bdw-gc"].opt_include/"gc"}"

    args = %W[
      -DENABLE_GTESTS=OFF
      -DP4C_USE_PREINSTALLED_ABSEIL=ON
      -DP4C_USE_PREINSTALLED_BDWGC=ON
      -DP4C_USE_PREINSTALLED_PROTOBUF=ON
      -DENABLE_ABSEIL_STATIC=OFF
      -DENABLE_PROTOBUF_STATIC=OFF
      -DENABLE_MULTITHREAD=ON
      -DENABLE_LTO=ON
      -DFETCHCONTENT_SOURCE_DIR_P4RUNTIME=#{buildpath/"p4runtime"}
    ]

    if OS.linux?
      # We use brewed `libbpf`, so we don't need to fetch it.
      # Make CMake's FetchContent happy.
      (bpfrepo = buildpath/"bpfrepo").mkpath
      args << "-DFETCHCONTENT_SOURCE_DIR_BPFREPO=#{bpfrepo}"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    resource "homebrew-basic.p4" do
      url "https://raw.githubusercontent.com/p4lang/tutorials/9797933eaa21a63aa9d49f937f0db313e26875f8/exercises/basic/solution/basic.p4"
      sha256 "41b0e4b3d06c7c8bd79e9c22db1835c356e580eca39f639a9c966cb789ff614a"
    end
    testpath.install resource("homebrew-basic.p4")

    system bin/"p4c", "basic.p4"
    assert_predicate testpath/"basic.json", :exist?
    assert_predicate testpath/"basic.p4i", :exist?
  end
end
