# frozen_string_literal: true

class FieldSlipJob < ApplicationJob
  queue_as :default

  def perform(*args)
    filename = "tmp/fs-#{Time.now.to_i}.txt"
    File.write(filename, args.to_s)
    filename
  end
end
