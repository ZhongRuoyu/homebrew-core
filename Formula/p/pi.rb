class Pi < Formula
  desc "Implementation framework for a P4Runtime server"
  homepage "https://github.com/p4lang/PI"
  url "https://github.com/p4lang/PI/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "f0f52602ce4b2576f58f9a5d9721550a41f3e583406de0788f63310b4d4e9c29"
  license "Apache-2.0"
  head "https://github.com/p4lang/PI.git", branch: "main"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "uthash" => :build
  depends_on "abseil"
  depends_on "boost"
  depends_on "grpc"
  depends_on "nanomsg"
  depends_on "protobuf"
  depends_on "readline"

  # Use the commit in https://github.com/p4lang/PI/tree/v#{version}/proto/openconfig
  resource "gnmi" do
    url "https://github.com/openconfig/gnmi/archive/9c8d9e965b3e854107ea02c12ab11b70717456f2.tar.gz"
    sha256 "a471616d977c01a2735e73bf69c1c569d14b796cab11d07fc4625a1a1ae03613"
  end

  # Use the commit in https://github.com/p4lang/PI/tree/v#{version}/proto/openconfig
  resource "public" do
    url "https://github.com/openconfig/public/archive/1040d11c089c74084c64c234bee3691ec70e8a9f.tar.gz"
    sha256 "592236c0eaf29fd6c1bb7e4cd9e8ee19e65d3b8c82c825573b99eec5f9a61164"
  end

  # Use the commit in https://github.com/p4lang/PI/tree/v#{version}/proto
  resource "p4runtime" do
    url "https://github.com/p4lang/p4runtime/archive/e9c0d196c4c2acd6f1bd3439f5b30b423ef90c95.tar.gz"
    sha256 "6a811ba05831da518cbdffc6e1781a565bdf082e3988ed7a61b89bd44ab57265"
  end

  def install
    # Remove bundled dependencies.
    %w[googletest unity uthash].each do |dep|
      rm_r buildpath/"third_party"/dep
      inreplace "configure.ac", "third_party/#{dep}/Makefile", "", false
      inreplace "third_party/Makefile.am" do |s|
        s.gsub! /^include #{dep}.am$/, "", false
        s.gsub! /^SUBDIRS =(.*) #{dep}(( .*)?)$/, 'SUBDIRS =\1\2', false
      end
    end
    inreplace "configure.ac",
              'AM_CONDITIONAL([WITH_GTEST], [test "$with_proto" = yes])',
              "AM_CONDITIONAL([WITH_GTEST], [false])"

    {
      "gnmi"      => "proto/openconfig/gnmi",
      "public"    => "proto/openconfig/public",
      "p4runtime" => "proto/p4runtime",
    }.each do |name, path|
      resource(name).stage buildpath/path
    end

    system "./autogen.sh"

    args = %W[
      --with-fe-cpp
      --with-proto
      --with-internal-rpc
      --with-cli
      --with-boost-libdir=#{Formula["boost"].opt_lib}
    ]
    system "./configure", *std_configure_args, *args
    system "make"
    system "make", "install"
  end

  test do
    resource "homebrew-simple_router.json" do
      url "https://raw.githubusercontent.com/p4lang/PI/v0.1.0/tests/testdata/simple_router.json"
      sha256 "d5581633f6a2fcfad1d1409eae21ccbe03f1c01be78ed75c05f4fa81acd99a09"
    end
    testpath.install resource("homebrew-simple_router.json")

    refute_empty shell_output("#{bin}/pi_gen_native_json simple_router.json")
  end
end
