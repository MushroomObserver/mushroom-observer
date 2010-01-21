#!/usr/bin/env ruby

module RTF
   # This class represents a definition for a paper size and provides a set
   # of class constants for common paper sizes. An instance of the Paper class
   # is considered immutable after creation.
   class Paper
      # Attribute accessor.
      attr_reader :name, :width, :height
      
      
      # This is the constructor for the Paper class. All dimension parameters
      # to this method are in twips.
      #
      # ==== Parameters
      # name::    The name for the paper object.
      # width::   The width of the paper in portrait mode.
      # height::  The height of the paper in portrait mode.
      def initialize(name, width, height)
         @name   = name
         @width  = width
         @height = height
      end

      # Definition of an international paper constant.
      A0                     = Paper.new('A0', 47685, 67416)

      # Definition of an international paper constant.
      A1                     = Paper.new('A1', 33680, 47685)

      # Definition of an international paper constant.
      A2                     = Paper.new('A2', 23814, 33680)

      # Definition of an international paper constant.
      A3                     = Paper.new('A3', 16840, 23814)

      # Definition of an international paper constant.
      A4                     = Paper.new('A4', 11907, 16840)

      # Definition of an international paper constant.
      A5                     = Paper.new('A5', 8392, 11907)

      # Definition of a US paper constant.
      LETTER                 = Paper.new('Letter', 12247, 15819)

      # Definition of a US paper constant.
      LEGAL                  = Paper.new('Legal', 12247, 20185)

      # Definition of a US paper constant.
      EXECUTIVE              = Paper.new('Executive', 10773, 14402)

      # Definition of a US paper constant.
      LEDGER_TABLOID         = Paper.new('Ledger/Tabloid', 15819, 24494)
   end # End of the Paper class.
end # End of the RTF module.