# frozen_string_literal: true

#
#  = Functional Test Case
#
#  The test case class that all functional tests currently derive from.
#  Includes:
#
#  1. Some general-purpose helpers and assertions from GeneralExtensions.
#  2. Some controller-related helpers and assertions from ControllerExtensions.
#  3. A few helpers that encapsulate testing the flash error mechanism.
#
################################################################################

class FunctionalTestCase < ActionDispatch::IntegrationTest
  include GeneralExtensions
  include FlashExtensions
  include ControllerExtensions
  include CheckForUnsafeHtml

  # temporarily silence deprecation warnings
  # ActiveSupport::Deprecation.silenced = true

  # Commented out on purpose, retiring these modifications of base methods - AN
  # def get(*args, &block)
  #   args = check_for_params(args)
  #   super(*args, &block)
  #   check_for_unsafe_html!
  # end
  #
  # def post(*args, &block)
  #   args = extract_body(check_for_params(args))
  #   super(*args, &block)
  #   check_for_unsafe_html!
  # end
  #
  # def put(*args, &block)
  #   args = check_for_params(args)
  #   super(*args, &block)
  #   check_for_unsafe_html!
  # end
  #
  # def delete(*args, &block)
  #   args = check_for_params(args)
  #   super(*args, &block)
  #   check_for_unsafe_html!
  # end

  # def check_for_params(args)
  #   return args if (args.length < 2) || args[1][:params]
  #
  #   [args[0], { params: args[1] }] + args[2..]
  # end

  def extract_body(args)
    if args.length >= 2
      params = args[1][:params]
      args[1][:body] = params.delete(:body).read if params.member?(:body)
    end
    args
  end
end
