# frozen_string_literal: true

# This has to be done without access to Language because it is used
# to declare tasks before the MO environment has been loaded.
def all_locales
  locales = []
  Dir.glob("#{::Rails.root}/config/locales/*.yml").each do |file|
    match = /(\w+).yml$/.match(file)
    locales << match[1] if match
  end
  locales
end

def define_tasks(action, verbose, verbose_method, description)
  desc(description.gsub(/XXX/, "official").gsub(/\(S\)/, ""))
  task(official: :setup) do
    lang = Language.official
    lang.verbose(verbose + " " + lang.send(verbose_method))
    lang.send(action)
  end

  desc(description.gsub(/XXX/, "unofficial").gsub(/\(S\)/, "s"))
  task(unofficial: :setup) do
    Language.unofficial.each do |lang|
      lang.verbose(verbose + " " + lang.send(verbose_method))
      lang.send(action)
    end
  end

  desc(description.gsub(/XXX/, "all").gsub(/\(S\)/, "s"))
  task(all: :setup) do
    Language.all.each do |lang|
      lang.verbose(verbose + " " + lang.send(verbose_method))
      lang.send(action)
    end
  end

  all_locales.each do |locale|
    desc description.gsub(/XXX/, locale).gsub(/\(S\)/, "")
    task(locale => :setup) do |task|
      lang = Language.find_by(locale: task.name.sub(/.*:/, ""))
      lang.verbose(verbose + " " + lang.send(verbose_method))
      lang.send(action)
    end
  end
end

namespace :lang do
  desc "Check syntax of official export file, integrate changes into database,"\
       " refresh YAML and export files."
  task update: [
    "check:official",    # check syntax of official file
    "import:official",   # import any changes from official file
    "strip:all",         # strip out any strings we no longer need
    "update:all",        # update localization (YAML) files
    # update export (text) files (used by translation controller to build form)
    "export:unofficial"
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

  desc "Log in user for import tasks."
  task(:login) do
    User.current = if ENV.include?("user_name")
                     User.find_by(login: ENV["user_name"])
                   elsif ENV.include?("user_id")
                     User.find(ENV["user_id"])
                   end
  end

  desc "Log in admin for import tasks."
  task(:login_admin) do
    User.current = User.find(0)
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
end
