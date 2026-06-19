# frozen_string_literal: true

# The textile sandbox GET URL moved from /info/textile_sandbox to
# /info/textile_sandbox/new. Translation strings that embed the old URL
# as raw <a href="..."> markup need to be updated. Some translations
# still reference the even-older /observer/textile redirect; fix those too.
class FixTextileSandboxUrlsInTranslations < ActiveRecord::Migration[7.2]
  OLD_URLS = [
    '/observer/textile"',
    '/observer/textile_sandbox"',
    '/info/textile_sandbox"'
  ].freeze
  NEW_URL = '/info/textile_sandbox/new"'

  def up
    # Use nested REPLACE() so a single SQL statement handles all three
    # old URL variants without risk of double-replacing already-updated rows
    # (the new URL ends in /new" which doesn't match any of the old patterns).
    execute(<<~SQL.squish)
      UPDATE translation_strings
      SET text = REPLACE(
            REPLACE(
              REPLACE(text,
                '/observer/textile"',       '/info/textile_sandbox/new"'),
              '/observer/textile_sandbox"', '/info/textile_sandbox/new"'),
            '/info/textile_sandbox"',       '/info/textile_sandbox/new"')
      WHERE text LIKE '%/observer/textile%'
         OR text LIKE '%/info/textile_sandbox%'
    SQL
  end

  def down
    execute(<<~SQL.squish)
      UPDATE translation_strings
      SET text = REPLACE(text,
            '/info/textile_sandbox/new"', '/info/textile_sandbox"')
      WHERE text LIKE '%/info/textile_sandbox/new%'
    SQL
  end
end
