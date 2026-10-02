# frozen_string_literal: true

# Resolved once by the :login/:login_admin tasks, read by the :import
# action below - a plain rake-process-scoped value, not a model-layer
# global; nothing outside this file reads it. attr_reader/attr_writer
# don't work at top-level scope (no Module context), so plain def.
# rubocop:disable Style/TrivialAccessors
def login_user
  @login_user
end

def login_user=(user)
  @login_user = user
end
# rubocop:enable Style/TrivialAccessors

# This has to be done without access to Language because it is used
# to declare tasks before the MO environment has been loaded.
def all_locales
  locales = []
  Rails.root.glob("config/locales/*.yml").each do |file|
    match = /(\w+).yml$/.match(file.to_s)
    locales << match[1] if match
  end
  locales
end

# import_from_file is the one action that needs an explicit user
# (resolved by :login/:login_admin above); every other action takes
# no arguments.
def perform_action(lang, action)
  if action == :import_from_file
    lang.send(action, login_user)
  else
    lang.send(action)
  end
end

# Each Language's export/import/update/strip/check work is independent
# (own instance variables, own "#{locale}.yml"/"#{locale}.txt" files).
# The class-level state this call path touches --
# Language.verbose/safe_mode/locales_dir -- is set once by the :setup
# prerequisite chain before this runs and never written to during it,
# so concurrent reads are safe. (Language.for_locale has its own
# memoized cache, but nothing reachable from here calls it.) See
# ConcurrentEachWithConnection for why this parallelizes in-process.
#
# Built lazily (not a top-level constant): rake files are evaluated
# before :environment, so Zeitwerk can't resolve the constant yet.
# Not memoized -- the wrapper only holds `pool_size`; the real thread
# pool is built fresh inside every #call, so caching it saves nothing.
def lang_task_pool
  ConcurrentEachWithConnection.new(pool_size: 4)
end

def define_tasks(action, verbose, verbose_method, description)
  desc(description.gsub("XXX", "official").gsub("(S)", ""))
  task(official: :setup) do
    lang = Language.official
    lang.verbose("#{verbose} #{lang.send(verbose_method)}")
    perform_action(lang, action)
  end

  # `lang.verbose` puts when `Language.verbose` is on (default unless
  # `silent=yes`). Threaded output can interleave across locales --
  # harmless, since each line is already locale-tagged (e.g. "Checking
  # en") and nothing parses this task's stdout.
  desc(description.gsub("XXX", "unofficial").gsub("(S)", "s"))
  task(unofficial: :setup) do
    lang_task_pool.call(Language.unofficial.to_a) do |lang|
      lang.verbose("#{verbose} #{lang.send(verbose_method)}")
      perform_action(lang, action)
    end
  end

  desc(description.gsub("XXX", "all").gsub("(S)", "s"))
  task(all: :setup) do
    lang_task_pool.call(Language.all.to_a) do |lang|
      lang.verbose("#{verbose} #{lang.send(verbose_method)}")
      perform_action(lang, action)
    end
  end

  all_locales.each do |locale|
    desc(description.gsub("XXX", locale).gsub("(S)", ""))
    task(locale => :setup) do |task|
      lang = Language.find_by(locale: task.name.sub(/.*:/, ""))
      lang.verbose("#{verbose} #{lang.send(verbose_method)}")
      perform_action(lang, action)
    end
  end
end

namespace :lang do
  desc "Check syntax of official export file, " \
       "integrate changes into database, " \
       "refresh export files."
  task update: [
    "check:official",    # check syntax of official file
    "import:official",   # import any changes from official file
    "strip:all",         # strip out any strings we no longer need
    "export:unofficial"  # (still needed by some tests)
    # update:all (regenerate every locale's YAML) deliberately NOT run
    # here anymore -- translations are DB/Solid-Cache-backed at runtime
    # (#4807), nothing reads config/locales/*.yml anymore. The
    # lang:update:* tasks below still exist for a manual/backup
    # snapshot if ever wanted.
  ]

  desc "Find en.txt tags with no remaining reference anywhere " \
       "(issue #4867 purge audit -- prints a candidate list, " \
       "does not delete anything)."
  task find_unused_tags: :environment do
    result = Language::UnusedTagFinder.call
    puts("Scanned #{result.files_scanned} files.")
    puts("Total tags: #{result.total}")
    puts("Protected (dynamic-construction risk): " \
         "#{result.protected_tags.size}")
    puts("Confirmed unused: #{result.confirmed_unused.size}")
    puts
    result.confirmed_unused.each { |tag| puts("  #{tag}") }
  end

  [
    [:check,  :check_export_syntax,      "Checking",  :export_file,
     "Check syntax of XXX YAML file(S)."],
    [:strip,  :strip,                    "Stripping", :locale,
     "Strip unused tags in XXX locale(S) from database."],
    [:update, :update_localization_file, "Updating",  :localization_file,
     "Update the XXX YAML file(S) from database."],
    [:export, :update_export_file,       "Exporting", :export_file,
     "Export XXX locale(S) to text file(S)."],
    [:import, :import_from_file,         "Importing", :export_file,
     "Import XXX locale(S) from text file(S)."]
  ].each do |namespace_name, action, verbose, verbose_method, description|
    namespace namespace_name do
      define_tasks(action, verbose, verbose_method, description)
    end
  end

  desc "Setup environment for language tasks."
  task setup: [:environment, :login, :verbose, :safe_mode]

  # Disable cop out of caution; our translation stuff is kind of wonky
  # See https://github.com/MushroomObserver/mushroom-observer/pull/2838/commits/fcf75b4c57ac7c6f0a3046c870236ceeda50e50f#r2011104991
  # rubocop:disable Rails/RakeEnvironment
  desc "Log in user for import tasks."
  task(:login) do
    self.login_user = if ENV.include?("user_name")
                        User.find_by(login: ENV["user_name"])
                      elsif ENV.include?("user_id")
                        User.find(ENV["user_id"])
                      end
  end

  desc "Log in admin for import tasks."
  task(:login_admin) do
    self.login_user = User.find(0)
  end

  desc 'Turn off verbosity if include "silent=yes".'
  task(:verbose) do
    Language.verbose = true unless ENV.include?("silent")
  end

  desc 'Turn on safe mode if include "safe=yes".'
  task(:safe_mode) do
    if ENV.include?("safe")
      Language.safe_mode = true
      puts("*** SAFE MODE ***")
    end
  end
  # rubocop:enable Rails/RakeEnvironment
end
