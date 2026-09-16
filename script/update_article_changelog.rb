# frozen_string_literal: true

# Publishes article_pending.textile (written by the pre-release PR,
# see script/prerelease.rb and issue #5155) into the MO Article
# changelog. Run by script/deploy.sh after a pre-release deploy; safe
# to re-run by hand if that step failed.
#
#   Dry run (default -- reports what WOULD change, writes nothing):
#     bundle exec rails runner script/update_article_changelog.rb
#   Live run:
#     bundle exec rails runner script/update_article_changelog.rb --apply
#
# The rows are inserted just below the article's table header line.
# Idempotent: if the article body already contains the first pending
# row, nothing is written (covers a re-run after a failed deploy step
# and a deploy with a stale, already-published file).
#
# The article id is bumped by hand at yearly rollover (create the next
# year's article, update the constant) -- article creation is not
# automated.
ARTICLE_ID = 55
PENDING_FILE = "article_pending.textile"
HEADER_ROW = "| +date+ | +what+ | +link+ |"
SCRIPT = "bundle exec rails runner script/update_article_changelog.rb"

args = ARGV.dup
apply = args.delete("--apply") ? true : false
abort("Unknown arguments: #{args.join(" ")}") unless args.empty?

unless File.exist?(PENDING_FILE)
  puts("No #{PENDING_FILE}; nothing to publish.")
  exit(0)
end

rows = File.read(PENDING_FILE).lines.map(&:chomp).reject(&:empty?)
if rows.empty?
  puts("#{PENDING_FILE} is empty; nothing to publish.")
  exit(0)
end

article = Article.find(ARTICLE_ID)

if article.body.to_s.include?(rows.first)
  puts("Article #{ARTICLE_ID} already contains the first pending row; " \
       "nothing to publish.")
  exit(0)
end

# The body may carry CRLF line endings (it is pasted through a web
# form); insert with whatever the body uses.
eol = article.body.to_s.include?("\r\n") ? "\r\n" : "\n"
lines = article.body.to_s.split(/\r?\n/, -1)
header_index = lines.index { |line| line.strip == HEADER_ROW }
unless header_index
  abort("Article #{ARTICLE_ID} has no #{HEADER_ROW.inspect} header " \
        "line; fix the article body, then re-run: #{SCRIPT} --apply")
end

puts("Inserting #{rows.size} row(s) below the header of Article " \
     "#{ARTICLE_ID} (#{article.title}):")
rows.each { |row| puts("  #{row}") }

unless apply
  puts("Dry run - nothing written. To apply: #{SCRIPT} --apply")
  exit(0)
end

new_lines = lines[0..header_index] + rows + lines[(header_index + 1)..]
# update_columns: Article autologs updates to the activity feed, and a
# routine changelog append should not post a feed entry per deploy.
article.update_columns(body: new_lines.join(eol),
                       updated_at: Time.zone.now)
puts("Done: Article #{ARTICLE_ID} updated.")
