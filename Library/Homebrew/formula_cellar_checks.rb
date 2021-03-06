require "utils/shell"

module FormulaCellarChecks
  def check_env_path(bin)
    # warn the user if stuff was installed outside of their PATH
    return unless bin.directory?
    return if bin.children.empty?

    prefix_bin = (HOMEBREW_PREFIX/bin.basename)
    return unless prefix_bin.directory?

    prefix_bin = prefix_bin.realpath
    return if ORIGINAL_PATHS.include? prefix_bin

    <<~EOS
      #{prefix_bin} is not in your PATH
      You can amend this by altering your #{Utils::Shell.profile} file
    EOS
  end

  def check_manpages
    # Check for man pages that aren't in share/man
    return unless (formula.prefix/"man").directory?

    <<~EOS
      A top-level "man" directory was found
      Homebrew requires that man pages live under share.
      This can often be fixed by passing "--mandir=\#{man}" to configure.
    EOS
  end

  def check_infopages
    # Check for info pages that aren't in share/info
    return unless (formula.prefix/"info").directory?

    <<~EOS
      A top-level "info" directory was found
      Homebrew suggests that info pages live under share.
      This can often be fixed by passing "--infodir=\#{info}" to configure.
    EOS
  end

  def check_jars
    return unless formula.lib.directory?

    jars = formula.lib.children.select { |g| g.extname == ".jar" }
    return if jars.empty?

    <<~EOS
      JARs were installed to "#{formula.lib}"
      Installing JARs to "lib" can cause conflicts between packages.
      For Java software, it is typically better for the formula to
      install to "libexec" and then symlink or wrap binaries into "bin".
      See "activemq", "jruby", etc. for examples.
      The offending files are:
        #{jars * "\n        "}
    EOS
  end

  VALID_LIBRARY_EXTENSIONS = %w[.a .jnilib .la .o .so .jar .prl .pm .sh].freeze

  def valid_library_extension?(filename)
    VALID_LIBRARY_EXTENSIONS.include? filename.extname
  end
  alias generic_valid_library_extension? valid_library_extension?

  def check_non_libraries
    return unless formula.lib.directory?

    non_libraries = formula.lib.children.reject do |g|
      next true if g.directory?

      valid_library_extension? g
    end
    return if non_libraries.empty?

    <<~EOS
      Non-libraries were installed to "#{formula.lib}"
      Installing non-libraries to "lib" is discouraged.
      The offending files are:
        #{non_libraries * "\n        "}
    EOS
  end

  def check_non_executables(bin)
    return unless bin.directory?

    non_exes = bin.children.select { |g| g.directory? || !g.executable? }
    return if non_exes.empty?

    <<~EOS
      Non-executables were installed to "#{bin}"
      The offending files are:
        #{non_exes * "\n  "}
    EOS
  end

  def check_generic_executables(bin)
    return unless bin.directory?

    generic_names = %w[run service start stop]
    generics = bin.children.select { |g| generic_names.include? g.basename.to_s }
    return if generics.empty?

    <<~EOS
      Generic binaries were installed to "#{bin}"
      Binaries with generic names are likely to conflict with other software,
      and suggest that this software should be installed to "libexec" and then
      symlinked as needed.

      The offending files are:
        #{generics * "\n        "}
    EOS
  end

  def check_easy_install_pth(lib)
    pth_found = Dir["#{lib}/python{2.7,3}*/site-packages/easy-install.pth"].map { |f| File.dirname(f) }
    return if pth_found.empty?

    <<~EOS
      easy-install.pth files were found
      These .pth files are likely to cause link conflicts. Please invoke
      setup.py using Language::Python.setup_install_args.
      The offending files are
        #{pth_found * "\n        "}
    EOS
  end

  def check_elisp_dirname(share, name)
    return unless (share/"emacs/site-lisp").directory?
    # Emacs itself can do what it wants
    return if name == "emacs"

    bad_dir_name = (share/"emacs/site-lisp").children.any? do |child|
      child.directory? && child.basename.to_s != name
    end

    return unless bad_dir_name

    <<~EOS
      Emacs Lisp files were installed into the wrong site-lisp subdirectory.
      They should be installed into:
      #{share}/emacs/site-lisp/#{name}
    EOS
  end

  def check_elisp_root(share, name)
    return unless (share/"emacs/site-lisp").directory?
    # Emacs itself can do what it wants
    return if name == "emacs"

    elisps = (share/"emacs/site-lisp").children.select { |file| %w[.el .elc].include? file.extname }
    return if elisps.empty?

    <<~EOS
      Emacs Lisp files were linked directly to #{HOMEBREW_PREFIX}/share/emacs/site-lisp
      This may cause conflicts with other packages.
      They should instead be installed into:
      #{share}/emacs/site-lisp/#{name}

      The offending files are:
        #{elisps * "\n        "}
    EOS
  end

  def audit_installed
    @new_formula ||= false

    problem_if_output(check_manpages)
    problem_if_output(check_infopages)
    problem_if_output(check_jars)
    problem_if_output(check_non_libraries) if @new_formula
    problem_if_output(check_non_executables(formula.bin))
    problem_if_output(check_generic_executables(formula.bin))
    problem_if_output(check_non_executables(formula.sbin))
    problem_if_output(check_generic_executables(formula.sbin))
    problem_if_output(check_easy_install_pth(formula.lib))
    problem_if_output(check_elisp_dirname(formula.share, formula.name))
    problem_if_output(check_elisp_root(formula.share, formula.name))
  end
  alias generic_audit_installed audit_installed

  private

  def relative_glob(dir, pattern)
    File.directory?(dir) ? Dir.chdir(dir) { Dir[pattern] } : []
  end
end

require "extend/os/formula_cellar_checks"
