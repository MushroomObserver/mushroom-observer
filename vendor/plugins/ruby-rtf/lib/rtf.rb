#!/usr/bin/env ruby

require 'stringio'
require 'rtf/font'
require 'rtf/colour'
require 'rtf/style'
require 'rtf/information'
require 'rtf/paper'
require 'rtf/node'

# This module encapsulates all the classes and definitions relating to the RTF
# library.
module RTF
   # This is the exception class used by the RTF library code to indicate
   # errors.
   class RTFError < StandardError
      # This is the constructor for the RTFError class.
      #
      # ==== Parameters
      # message::  A reference to a string containing the error message for
      #            the exception defaults to nil.
      def initialize(message=nil)
         super(message == nil ? 'No error message available.' : message)
      end

      # This method provides a short cut for raising RTFErrors.
      #
      # ==== Parameters
      # message::  A string containing the exception message. Defaults to nil.
      def RTFError.fire(message=nil)
         raise RTFError.new(message)
      end
   end # End of the RTFError class.
end # End of the RTF module.