# Load all our class extensions. *NOTE*: These will not auto-load because the
# class (presumably) already exists. This is required by ApplicationController.
# Rake tasks, depending on their environment, might need to require this
# explicitly, too.  (Although, I believe ApplicationController is always
# loaded, no matter what you need(?)...)

for file in Dir[File.expand_path("../*_extensions.rb", __FILE__)]
  require_dependency file
end
