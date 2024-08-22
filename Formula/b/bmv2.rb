class Bmv2 < Formula
  desc "Reference P4 software switch"
  homepage "https://github.com/p4lang/behavioral-model"
  url "https://github.com/p4lang/behavioral-model/archive/refs/tags/1.15.0.tar.gz"
  sha256 "6690ee1dc1b8fcd4bfdb1b2a95b5c7950aed689dbaa7f279913e004666594299"
  license "Apache-2.0"
  head "https://github.com/p4lang/behavioral-model.git", branch: "main"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "abseil"
  depends_on "boost"
  depends_on "gmp"
  depends_on "grpc"
  depends_on "openssl@3"
  depends_on "pi"
  depends_on "protobuf"

  uses_from_macos "libpcap"

  def install
    system "./autogen.sh"

    # Thrift support requires Python bindings not available in brewed `thrift`.
    # Nanomsg support requires an unmaintained Python package.
    args = %w[
      --with-pi
      --without-thrift
      --without-nanomsg
    ]
    system "./configure", *std_configure_args, *args
    system "make"
    system "make", "install"

    cd "targets/simple_switch_grpc" do
      system "./autogen.sh"
      system "./configure", *std_configure_args
      system "make"
      system "make", "install"
    end
  end

  test do
    success = false
    PTY.spawn bin/"simple_switch_grpc", "--no-p4" do |r, _, pid|
      r.each_line do |line|
        if line.include? "Server listening"
          success = true
          break
        end
      end
    ensure
      Process.kill("TERM", pid)
    end

    assert success, "Server did not start successfully"
  end
end
