# frozen_string_literal: true

class ParallelTestConfigService::StdoutOutputHandler
  delegate :puts, :print, to: :$stdout
end
