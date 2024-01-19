# frozen_string_literal: true

# https://dev.to/ayushn21/applying-monkey-patches-in-rails-1bj1
# https://binarysolo.chapter24.blog/applying-monkey-patches-in-rails/
# https://www.justinweiss.com/articles/3-ways-to-monkey-patch-without-making-a-mess/
require("action_view/log_subscriber")

# Require all Ruby files in the core_extensions directory
Dir[Rails.root.join("lib/core_extensions/**/*.rb")].each { |f| require f }

# ActiveSupport.on_load(:action_view) do
# ActionView::LogSubscriber.include(CoreExtensions::ActionView::LogSubscriber)
# end

class ActionView::LogSubscriber
  prepend CoreExtensions::ActionView::LogSubscriber
end
