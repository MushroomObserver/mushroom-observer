# frozen_string_literal: true

# Runs a block once per item, up to `pool_size` at a time, each on its
# own ActiveRecord connection -- for work that has to parallelize
# in-process rather than as a background job (e.g. lib/tasks/lang.rake's
# multi-language tasks, which run standalone with no Solid Queue workers
# available).
#
# One item's failure doesn't stop the others; a single failure re-raises
# unchanged, two or more raise one combined RuntimeError naming all of
# them, so a run doesn't lose every failure but one.
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
