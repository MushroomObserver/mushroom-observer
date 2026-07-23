# frozen_string_literal: true

# Runs a block once per item, up to `pool_size` at a time, each on its
# own ActiveRecord connection. For work that has to parallelize
# in-process rather than as a background job -- e.g. lib/tasks/lang.rake's
# multi-language export/import tasks, which run standalone (CI, a git
# hook, or a developer directly) with no Solid Queue workers running.
#
# One item's failure doesn't stop the others from completing, but the
# overall call still fails loud once everything settles: a single
# failure re-raises that exact error (class + message unchanged); two
# or more failures raise one RuntimeError listing every one of them,
# so a deploy-time run doesn't lose N-1 failures' worth of diagnostic
# information behind whichever error happened to be collected first.
#
# @example
#   ConcurrentEachWithConnection.new(pool_size: 4).call(Language.all) do |lang|
#     lang.update_localization_file
#   end
class ConcurrentEachWithConnection
  def initialize(pool_size: 4)
    @pool_size = pool_size
  end

  def call(items, &block)
    raise(ArgumentError.new("block required")) unless block

    errors = Concurrent::Array.new
    pool = Concurrent::FixedThreadPool.new(@pool_size)
    begin
      items.each { |item| post_item(pool, item, errors, &block) }
    ensure
      pool.shutdown
      pool.wait_for_termination
    end
    raise_errors(errors)
  end

  private

  def post_item(pool, item, errors, &block)
    pool.post do
      ActiveRecord::Base.connection_pool.with_connection do
        yield(item)
      end
    rescue StandardError => e
      errors << e
    end
  end

  def raise_errors(errors)
    return if errors.empty?
    raise(errors.first) if errors.size == 1

    raise(combined_error_message(errors))
  end

  def combined_error_message(errors)
    details = errors.map { |e| "#{e.class}: #{e.message}" }.join("; ")
    "#{errors.size} errors: #{details}"
  end
end
