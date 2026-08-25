# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a test method that deliberately triggers a failure -- a
      # literal `raise`/`fail` written inside the test, typically
      # inside a `.stub(...)` block or `define_singleton_method` --
      # without also stubbing/capturing the logging call the
      # resulting rescue path makes (`warn`, `Rails.logger.error`,
      # `Rails.logger.warn`, or a custom `log` method). Left
      # un-stubbed, that log line hits the test logger, which writes
      # to $stdout -- the deliberate failure then dumps into the
      # test suite's console output looking like a failure in an
      # unrelated test.
      #
      # @example
      #   # bad
      #   def test_isolates_one_users_failure
      #     SomeMailer.stub(:build, ->(*) { raise("boom") }) do
      #       SomeService.run
      #     end
      #   end
      #
      #   # good
      #   def test_isolates_one_users_failure
      #     logged = nil
      #     Rails.logger.stub(:error, ->(msg) { logged = msg }) do
      #       SomeMailer.stub(:build, ->(*) { raise("boom") }) do
      #         SomeService.run
      #       end
      #     end
      #     assert_includes(logged, "boom")
      #   end
      class NoUncapturedTestLogging < Base
        MSG = "This test deliberately triggers a failure (raise) but " \
              "doesn't stub/capture the resulting warn/logger call -- " \
              "it prints to the test suite's console looking like a " \
              "failure elsewhere. Stub Rails.logger.error/warn (or the " \
              "relevant log method) to capture it instead."

        LOG_METHOD_NAMES = [:warn, :error, :log].freeze

        # Stubbing one of these to raise simulates a low-level I/O failure,
        # not a domain-logic one. MO's own rescues around them (File,
        # Tempfile, Open3, RestClient::Request) don't call Rails.logger --
        # they degrade silently (return false, retry, add a validation
        # error) or route through a caller-supplied, already-captured
        # output sink. A domain-class stub (Name, ExternalLink, API2, ...)
        # gets no such exemption -- its rescue path logging is unconfirmed.
        IO_PRIMITIVE_RECEIVERS = [:File, :Tempfile, :Open3, :Dir, :FileUtils,
                                  :IO, :RestClient].freeze

        def on_def(node)
          return unless node.method_name.to_s.start_with?("test_")
          return unless deliberate_raise?(node)
          return if captures_logging?(node)
          return if expects_propagation?(node)
          return if simulates_io_failure?(node)

          add_offense(node)
        end

        private

        def simulates_io_failure?(node)
          node.each_descendant(:send).any? do |send_node|
            next false unless send_node.method?(:stub) ||
                              send_node.method?(:define_singleton_method)

            io_primitive_receiver?(send_node.receiver)
          end
        end

        def io_primitive_receiver?(receiver)
          return false unless receiver&.const_type?

          root = receiver.const_name.to_s.split("::").first
          IO_PRIMITIVE_RECEIVERS.include?(root&.to_sym)
        end

        def deliberate_raise?(node)
          node.each_descendant(:send).any? do |send_node|
            [:raise, :fail].include?(send_node.method_name)
          end
        end

        # `assert_raises`/`assert_nothing_raised` means the raise is
        # meant to propagate straight out to the test's own
        # assertion, not be swallowed by a production rescue clause
        # that logs before continuing -- no log call to capture.
        def expects_propagation?(node)
          node.each_descendant(:send).any? do |send_node|
            [:assert_raises, :assert_nothing_raised].include?(
              send_node.method_name
            )
          end
        end

        def captures_logging?(node)
          node.each_descendant(:send).any? do |send_node|
            stub_capturing_log?(send_node) || singleton_log_override?(send_node)
          end
        end

        def stub_capturing_log?(send_node)
          return false unless send_node.method?(:stub)

          log_method_arg?(send_node)
        end

        def singleton_log_override?(send_node)
          return false unless send_node.method?(:define_singleton_method)

          log_method_arg?(send_node)
        end

        def log_method_arg?(send_node)
          arg = send_node.arguments.first
          arg&.sym_type? && LOG_METHOD_NAMES.include?(arg.value)
        end
      end
    end
  end
end
