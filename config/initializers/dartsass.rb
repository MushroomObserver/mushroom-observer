# frozen_string_literal: true

Rails.application.config.dartsass.builds = {
  "mushroom_observer.sass" => "mushroom_observer.css",
  "Admin.scss" => "Admin.css",
  "Agaricus.scss" => "Agaricus.css",
  "Amanita.scss" => "Amanita.css",
  "BlackOnWhite.scss" => "BlackOnWhite.css",
  "Cantharellaceae.scss" => "Cantharellaceae.css",
  "Hygrocybe.scss" => "Hygrocybe.css",
  "Sudo.scss" => "Sudo.css"
}

# silence the deprecation warnings for Bootstrap 3, while active
Rails.application.config.dartsass.build_options << " --quiet-deps"
