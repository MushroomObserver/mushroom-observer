# encoding: utf-8
#
#  = Unit Test Case
#
#  The test case class that all unit tests currently derive from.  Includes:
#
#  1. Some general-purpose helpers and assertions from GeneralExtensions. 
#
################################################################################

class UnitTestCase < Test::Unit::TestCase
  include GeneralExtensions
end
