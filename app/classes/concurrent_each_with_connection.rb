# frozen_string_literal: true

# Runs a block once per item, up to `pool_size` at a time, each on its
# own ActiveRecord connection. For work that has to parallelize
# in-process rather than as a background job -- e.g. lib/tasks/lang.rake's
# multi-language export/import tasks, which run standalone (CI, a git
# hook, or a developer directly) with no Solid Queue workers running.
#
# Re-raises the first error encountered, but only after every thread
# has finished -- one item's failure doesn't stop the others from
# completing, but the overall call still fails loud once everything
# settles, matching plain #each's fail-loud contract.
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
    raise(errors.first) if errors.any?
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
end
