# Copyright 2009-2016 Homebrew contributors.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

class Vtk5 < Formula
  homepage "http://www.vtk.org"
  url "http://www.vtk.org/files/release/5.10/vtk-5.10.1.tar.gz" # update libdir below, too!
  sha256 "f1a240c1f5f0d84e27b57e962f8e4a78b166b25bf4003ae16def9874947ebdbb"
  head "git://vtk.org/VTK.git", :branch => "release-5.10"
  revision 2

  bottle do
    sha256 "6163db8061b417758f171492118dfc9f56e88db8bb6d0da9422a02ac10fac1c1" => :el_capitan
    sha256 "ae0df1d384aa6fb145fe264d19eb3021e5880a697652dd70c0d4bf405a1c04ae" => :yosemite
    sha256 "443c65770a671b09ca7d31ea22ab5907c857d467c054f08d0e6ea0a7a9db9f17" => :mavericks
  end

  deprecated_option "examples" => "with-examples"
  deprecated_option "qt-extern" => "with-qt-extern"
  deprecated_option "qt" => "with-qt"
  deprecated_option "python" => "with-python"
  deprecated_option "tcl" => "with-tcl"
  deprecated_option "remove-legacy" => "without-legacy"

  option :cxx11
  option "with-examples",   "Compile and install various examples"
  option "with-qt-extern",  "Enable Qt4 extension via non-Homebrew external Qt4"
  option "with-tcl",        "Enable Tcl wrapping of VTK classes"
  option "without-legacy",  "Disable legacy APIs"

  depends_on "cmake" => :build
  depends_on :x11 => :optional
  depends_on "qt" => :optional
  depends_on "python@2" => :recommended
  # If --with-qt and --with-python, then we automatically use PyQt, too!
  if build.with?("qt") && build.with?("python")
    depends_on "sip"
    depends_on "pyqt"
  end
  depends_on "boost" => :recommended
  depends_on "hdf5" => :recommended
  depends_on "jpeg" => :recommended
  depends_on "libpng" => :recommended
  depends_on "libtiff" => :recommended

  keg_only "Different versions of the same library"

  # Fix bug in Wrapping/Python/setup_install_paths.py: http://vtk.org/Bug/view.php?id=13699
  # and compilation on mavericks backported from head.
  patch :DATA

  stable do
    patch do
      # apply upstream patches for C++11 mode
      url "https://gist.github.com/sxprophet/7463815/raw/165337ae10d5665bc18f0bad645eff098f939893/vtk5-cxx11-patch.diff"
      sha256 "b5946abb41c3d6ede33df636fa1621bbb86c4092cdae7032e3fdc63a5478f03d"
    end
  end

  def install
    libdir = if build.head? then lib; else "#{lib}/vtk-5.10"; end

    args = std_cmake_args + %W[
      -DVTK_REQUIRED_OBJCXX_FLAGS=''
      -DVTK_USE_CARBON=OFF
      -DVTK_USE_TK=OFF
      -DBUILD_TESTING=OFF
      -DBUILD_SHARED_LIBS=ON
      -DIOKit:FILEPATH=#{MacOS.sdk_path}/System/Library/Frameworks/IOKit.framework
      -DCMAKE_INSTALL_RPATH:STRING=#{libdir}
      -DCMAKE_INSTALL_NAME_DIR:STRING=#{libdir}
      -DVTK_USE_SYSTEM_EXPAT=ON
      -DVTK_USE_SYSTEM_LIBXML2=ON
      -DVTK_USE_SYSTEM_ZLIB=ON
    ]

    args << "-DBUILD_EXAMPLES=" + ((build.with? "examples") ? "ON" : "OFF")

    if build.with?("qt") || build.with?("qt-extern")
      args << "-DVTK_USE_GUISUPPORT=ON"
      args << "-DVTK_USE_QT=ON"
      args << "-DVTK_USE_QVTK=ON"
    end

    args << "-DVTK_WRAP_TCL=ON" if build.with? "tcl"

    # Cocoa for everything except x11
    if build.with? "x11"
      args << "-DVTK_USE_COCOA=OFF"
      args << "-DVTK_USE_X=ON"
    else
      args << "-DVTK_USE_COCOA=ON"
    end

    unless MacOS::CLT.installed?
      # We are facing an Xcode-only installation, and we have to keep
      # vtk from using its internal Tk headers (that differ from OSX's).
      args << "-DTK_INCLUDE_PATH:PATH=#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Headers"
      args << "-DTK_INTERNAL_PATH:PATH=#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Headers/tk-private"
    end

    args << "-DVTK_USE_BOOST=ON" if build.with? "boost"
    args << "-DVTK_USE_SYSTEM_HDF5=ON" if build.with? "hdf5"
    args << "-DVTK_USE_SYSTEM_JPEG=ON" if build.with? "jpeg"
    args << "-DVTK_USE_SYSTEM_PNG=ON" if build.with? "libpng"
    args << "-DVTK_USE_SYSTEM_TIFF=ON" if build.with? "libtiff"
    args << "-DVTK_LEGACY_REMOVE=ON" if build.without? "legacy"

    ENV.cxx11 if build.cxx11?

    mkdir "build" do
      if build.with? "python"
        args << "-DVTK_WRAP_PYTHON=ON"
        # CMake picks up the system's python dylib, even if we have a brewed one.
        args << "-DPYTHON_LIBRARY='#{`python-config --prefix`.chomp}/lib/libpython2.7.dylib'"
        # Set the prefix for the python bindings to the Cellar
        args << "-DVTK_PYTHON_SETUP_ARGS:STRING='--prefix=#{prefix} --single-version-externally-managed --record=installed.txt'"
        if build.with? "pyqt"
          args << "-DVTK_WRAP_PYTHON_SIP=ON"
          args << "-DSIP_PYQT_DIR=" # {HOMEBREW_PREFIX}/share/sip""
        end
      end
      args << ".."
      system "cmake", *args
      system "make"
      system "make", "install"
    end

    (share+"vtk").install "Examples" if build.with? "examples"
  end

  def caveats
    s = ""
    s += <<~EOS
        Even without the --with-qt option, you can display native VTK render windows
        from python. Alternatively, you can integrate the RenderWindowInteractor
        in PyQt, PySide, Tk or Wx at runtime. Read more:
            import vtk.qt4; help(vtk.qt4) or import vtk.wx; help(vtk.wx)

        VTK5 is keg only in favor of VTK6. Add
            #{opt_prefix}/lib/python2.7/site-packages
        to your PYTHONPATH before using the python bindings.
    EOS

    if build.with? "examples"
      s += <<~EOS

        The scripting examples are stored in #{HOMEBREW_PREFIX}/share/vtk

      EOS
    end
    s.empty? ? nil : s
  end
end

__END__
diff --git a/Wrapping/Python/setup_install_paths.py b/Wrapping/Python/setup_install_paths.py
index 00f48c8..014b906 100755
--- a/Wrapping/Python/setup_install_paths.py
+++ b/Wrapping/Python/setup_install_paths.py
@@ -35,7 +35,7 @@ def get_install_path(command, *args):
                 option, value = string.split(arg,"=")
                 options[option] = value
             except ValueError:
-                options[option] = 1
+                options[arg] = 1

     # check for the prefix and exec_prefix
     try:
