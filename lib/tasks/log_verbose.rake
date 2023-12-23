# frozen_string_literal: true

# example: rake log db:migrate. Can be very helpful!
desc("Run any task with verbose logging, such as a migration")
task(log: :environment) do
  ActiveRecord::Base.logger = Logger.new($stdout)
end
