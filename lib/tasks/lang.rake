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

# Concurrency for the :all / :unofficial multi-language tasks below.
# lang:update runs standalone (via CI, a git hook, or a developer
# directly) -- Solid Queue workers aren't running when this task
# fires, so this can't be a background job; it has to parallelize
# in-process. Each Language's export/import/update/strip/check work
# is independent (its own instance variables, its own
# "#{locale}.yml"/"#{locale}.txt" files) -- the only shared state is
# Language.verbose/safe_mode/locales_dir, all set once by the :setup
# prerequisite chain *before* this runs and never written to during
# it, so concurrent reads are safe.
#
# Built lazily inside a method (not a top-level constant) -- rake
# files are evaluated before the :environment task runs, so Zeitwerk
# can't resolve ConcurrentEachWithConnection yet at file-load time.
# Not memoized: the object itself only holds `pool_size` (an Integer)
# -- the real Concurrent::FixedThreadPool is created fresh inside
# every #call, so caching this wrapper saves nothing.
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

  # NOTE: `lang.verbose(...)` (LanguageExporter#verbose) does a plain
  # `puts` when `Language.verbose` is on (the default
  # unless `silent=yes`). Running these per-language on a thread pool
  # means lines from different languages can interleave/print
  # out of order -- an accepted tradeoff of parallelizing, since each
  # line is already locale-tagged (e.g. "Checking en"), and nothing in
  # MO's CI or scripts parses this task's stdout.
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
       "refresh YAML and export files."
  task update: [
    "check:official",    # check syntax of official file
    "import:official",   # import any changes from official file
    "strip:all",         # strip out any strings we no longer need
    "update:all",        # update localization (YAML) files
    "export:unofficial"  # (still needed by some tests)
  ]

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
