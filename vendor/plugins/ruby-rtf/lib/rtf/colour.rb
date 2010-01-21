#!/usr/bin/env ruby

require 'stringio'

module RTF
   # This class represents a colour within a RTF document.
   class Colour
      # Attribute accessor.
      attr_reader :red, :green, :blue


      # This is the constructor for the Colour class.
      #
      # ==== Parameters
      # red::    The intensity setting for red in the colour. Must be an
      #          integer between 0 and 255.
      # green::  The intensity setting for green in the colour. Must be an
      #          integer between 0 and 255.
      # blue::   The intensity setting for blue in the colour. Must be an
      #          integer between 0 and 255.
      #
      # ==== Exceptions
      # RTFError::  Generated whenever an invalid intensity setting is
      #             specified for the red, green or blue values.
      def initialize(red, green, blue)
         if red.kind_of?(Integer) == false || red < 0 || red > 255
            RTFError.fire("Invalid red intensity setting ('#{red}') specified "\
                          "for a Colour object.")
         end
         if green.kind_of?(Integer) == false || green < 0 || green > 255
            RTFError.fire("Invalid green intensity setting ('#{green}') "\
                          "specified for a Colour object.")
         end
         if blue.kind_of?(Integer) == false || blue < 0 || blue > 255
            RTFError.fire("Invalid blue intensity setting ('#{blue}') "\
                          "specified for a Colour object.")
         end

         @red   = red
         @green = green
         @blue  = blue
      end

      # This method overloads the comparison operator for the Colour class.
      #
      # ==== Parameters
      # object::  A reference to the object to be compared with.
      def ==(object)
         object.instance_of?(Colour) &&
         object.red   == @red &&
         object.green == @green &&
         object.blue  == @blue
      end

      # This method returns a textual description for a Colour object.
      #
      # ==== Parameters
      # indent::  The number of spaces to prefix to the lines created by the
      #           method. Defaults to zero.
      def to_s(indent=0)
         prefix = indent > 0 ? ' ' * indent : ''
         "#{prefix}Colour (#{@red}/#{@green}/#{@blue})"
      end

      # This method generates the RTF text for a Colour object.
      #
      # ==== Parameters
      # indent::  The number of spaces to prefix to the lines created by the
      #           method. Defaults to zero.
      def to_rtf(indent=0)
         prefix = indent > 0 ? ' ' * indent : ''
         "#{prefix}\\red#{@red}\\green#{@green}\\blue#{@blue};"
      end
   end # End of the Colour class.


   # This class represents a table of colours used within a RTF document. This
   # class need not be directly instantiated as it will be used internally by,
   # and can be obtained from a Document object.
   class ColourTable
      # This is the constructor for the ColourTable class.
      #
      # ==== Parameters
      # *colours::  An array of zero or more colours that make up the colour
      #             table entries.
      def initialize(*colours)
         @colours = []
         colours.each {|colour| add(colour)}
      end

      # This method fetches a count of the number of colours within a colour
      # table.
      def size
         @colours.size
      end

      # This method adds a new colour to a ColourTable object. If the colour
      # already exists within the table or is not a Colour object then this
      # method does nothing.
      #
      # ==== Parameters
      # colour::  The colour to be added to the table.
      def add(colour)
         if colour.instance_of?(Colour)
            @colours.push(colour) if @colours.index(colour) == nil
         end
         self
      end

      # This method iterates over the contents of a ColourTable object. This
      # iteration does not include the implicit default colour entry.
      def each
         if block_given?
            @colours.each {|colour| yield colour}
         end
      end

      # This method overloads the array dereference operator for the ColourTable
      # class. It is not possible to dereference the implicit default colour
      # using this method. An invalid index will return a nil value.
      #
      # ==== Parameters
      # index::  The index of the colour to be retrieved.
      def [](index)
         @colours[index]
      end

      # This method retrieves the index of a specified colour within the table.
      # If the colour doesn't exist within the table then nil is returned. It
      # should be noted that the index of a colour will be one more than its
      # order of entry to account for the implicit default colour entry.
      #
      # ==== Parameters
      # colour::  The colour to retrieve the index of.
      def index(colour)
         index = @colours.index(colour)
         index == nil ? index : index + 1
      end

      # This method generates a textual description for a ColourTable object.
      #
      # ==== Parameters
      # indent::  The number of spaces to prefix to the lines generated by the
      #           method. Defaults to zero.
      def to_s(indent=0)
         prefix = indent > 0 ? ' ' * indent : ''
         text   = StringIO.new

         text << "#{prefix}Colour Table (#{@colours.size} colours)"
         @colours.each {|colour| text << "\n#{prefix}   #{colour}"}

         text.string
      end

      # This method generates the RTF text for a ColourTable object.
      #
      # ==== Parameters
      # indent::  The number of spaces to prefix to the lines generated by the
      #           method. Defaults to zero.
      def to_rtf(indent=0)
         prefix = indent > 0 ? ' ' * indent : ''
         text   = StringIO.new

         text << "#{prefix}{\\colortbl\n#{prefix};"
         @colours.each {|colour| text << "\n#{prefix}#{colour.to_rtf}"}
         text << "\n#{prefix}}"

         text.string
      end

      alias << add
   end # End of the ColourTable class.
end # End of the RTF module.