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
    affected.find_each do |ts|
      updated = OLD_URLS.reduce(ts.text) { |t, old| t.gsub(old, NEW_URL) }
      ts.update_column(:text, updated) if updated != ts.text
    end
  end

  def down
    col = TranslationString.arel_table[:text]
    TranslationString.where(col.matches("%#{NEW_URL}%")).find_each do |ts|
      updated = ts.text.gsub(NEW_URL, '/info/textile_sandbox"')
      ts.update_column(:text, updated) if updated != ts.text
    end
  end

  private

  def affected
    col = TranslationString.arel_table[:text]
    condition = OLD_URLS.map { |old| col.matches("%#{old}%") }.
                reduce(:or)
    TranslationString.where(condition)
  end
end
