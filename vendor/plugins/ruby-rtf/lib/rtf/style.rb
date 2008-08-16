#!/usr/bin/env ruby

require 'stringio'

module RTF
   # This is a parent class that all style classes will derive from.
   class Style
      # A definition for a character flow setting.
      LEFT_TO_RIGHT                              = :rtl

      # A definition for a character flow setting.
      RIGHT_TO_LEFT                              = :ltr

      # This method retrieves the command prefix text associated with a Style
      # object. This method always returns nil and should be overridden by
      # derived classes as needed.
      #
      # ==== Parameters
      # fonts::    A reference to the document fonts table. May be nil if no
      #            fonts are used.
      # colours::  A reference to the document colour table. May be nil if no
      #            colours are used.
      def prefix(fonts, colours)
         nil
      end

      # This method retrieves the command suffix text associated with a Style
      # object. This method always returns nil and should be overridden by
      # derived classes as needed.
      #
      # ==== Parameters
      # fonts::    A reference to the document fonts table. May be nil if no
      #            fonts are used.
      # colours::  A reference to the document colour table. May be nil if no
      #            colours are used.
      def suffix(fonts, colours)
         nil
      end

      # Used to determine if the style applies to characters. This method always
      # returns false and should be overridden by derived classes as needed.
      def is_character_style?
         false
      end

      # Used to determine if the style applies to paragraphs. This method always
      # returns false and should be overridden by derived classes as needed.
      def is_paragraph_style?
         false
      end

      # Used to determine if the style applies to documents. This method always
      # returns false and should be overridden by derived classes as needed.
      def is_document_style?
         false
      end

      # Used to determine if the style applies to tables. This method always
      # returns false and should be overridden by derived classes as needed.
      def is_table_style?
         false
      end
   end # End of the style class.


   # This class represents a character style for an RTF document.
   class CharacterStyle < Style
      # Attribute accessor.
      attr_reader :bold, :italic, :underline, :superscript, :capitalise,
                  :strike, :subscript, :hidden, :foreground, :background,
                  :flow, :font, :font_size

      # Attribute mutator.
      attr_writer :bold, :italic, :underline, :superscript, :capitalise,
                  :strike, :subscript, :hidden, :foreground, :background,
                  :flow, :font, :font_size

      # This is the constructor for the CharacterStyle class.
      #
      # ==== Exceptions
      # RTFError::  Generate if the parent style specified is not an instance
      #             of the CharacterStyle class.
      def initialize
         @bold        = false
         @italic      = false
         @underline   = false
         @superscript = false
         @capitalise  = false
         @strike      = false
         @subscript   = false
         @hidden      = false
         @foreground  = nil
         @background  = nil
         @font        = nil
         @font_size   = nil
         @flow        = LEFT_TO_RIGHT
      end

      # This method overrides the is_character_style? method inherited from the
      # Style class to always return true.
      def is_character_style?
         true
      end

      # This method generates a string containing the prefix associated with a
      # style object.
      #
      # ==== Parameters
      # fonts::    A reference to a FontTable containing any fonts used by the
      #            style (may be nil if no fonts used).
      # colours::  A reference to a ColourTable containing any colours used by
      #            the style (may be nil if no colours used).
      def prefix(fonts, colours)
         text = StringIO.new

         text << '\b' if @bold
         text << '\i' if @italic
         text << '\ul' if @underline
         text << '\super' if @superscript
         text << '\caps' if @capitalise
         text << '\strike' if @strike
         text << '\sub' if @subscript
         text << '\v' if @hidden
         text << "\\cf#{colours.index(@foreground)}" if @foreground != nil
         text << "\\cb#{colours.index(@background)}" if @background != nil
         text << "\\f#{fonts.index(@font)}" if @font != nil
         text << "\\fs#{@font_size.to_i}" if @font_size != nil
         text << '\rtlch' if @flow == RIGHT_TO_LEFT

         text.string.length > 0 ? text.string : nil
      end

      alias :capitalize :capitalise
      alias :capitalize= :capitalise=
   end # End of the CharacterStyle class.


   # This class represents a styling for a paragraph within an RTF document.
   class ParagraphStyle < Style
      # A definition for a paragraph justification setting.
      LEFT_JUSTIFY                     = :ql

      # A definition for a paragraph justification setting.
      RIGHT_JUSTIFY                    = :qr

      # A definition for a paragraph justification setting.
      CENTER_JUSTIFY                   = :qc

      # A definition for a paragraph justification setting.
      CENTRE_JUSTIFY                   = :qc

      # A definition for a paragraph justification setting.
      FULL_JUSTIFY                     = :qj

      # Attribute accessor.
      attr_reader :justification, :left_indent, :right_indent,
                  :first_line_indent, :space_before, :space_after,
                  :line_spacing, :flow

      # Attribute mutator.
      attr_writer :justification, :left_indent, :right_indent,
                  :first_line_indent, :space_before, :space_after,
                  :line_spacing, :flow

      # This is a constructor for the ParagraphStyle class.
      #
      # ==== Parameters
      # base::  A reference to base object that the new style will inherit its
      #         initial properties from. Defaults to nil.
      def initialize(base=nil)
         @justification     = base == nil ? LEFT_JUSTIFY : base.justification
         @left_indent       = base == nil ? nil : base.left_indent
         @right_indent      = base == nil ? nil : base.right_indent
         @first_line_indent = base == nil ? nil : base.first_line_indent
         @space_before      = base == nil ? nil : base.space_before
         @space_after       = base == nil ? nil : base.space_after
         @line_spacing      = base == nil ? nil : base.line_spacing
         @flow              = base == nil ? LEFT_TO_RIGHT : base.flow
      end

      # This method overrides the is_paragraph_style? method inherited from the
      # Style class to always return true.
      def is_paragraph_style?
         true
      end

      # This method generates a string containing the prefix associated with a
      # style object.
      #
      # ==== Parameters
      # fonts::    A reference to a FontTable containing any fonts used by the
      #            style (may be nil if no fonts used).
      # colours::  A reference to a ColourTable containing any colours used by
      #            the style (may be nil if no colours used).
      def prefix(fonts, colours)
         text = StringIO.new

         text << "\\#{@justification.id2name}"
         text << "\\li#{@left_indent}" if @left_indent != nil
         text << "\\ri#{@right_indent}" if @right_indent != nil
         text << "\\fi#{@first_line_indent}" if @first_line_indent != nil
         text << "\\sb#{@space_before}" if @space_before != nil
         text << "\\sa#{@space_after}" if @space_after != nil
         text << "\\sl#{@line_spacing}" if @line_spacing != nil
         text << '\rtlpar' if @flow == RIGHT_TO_LEFT

         text.string.length > 0 ? text.string : nil
      end
   end # End of the ParagraphStyle class.


   # This class represents styling attributes that are to be applied at the
   # document level.
   class DocumentStyle < Style
      # Definition for a document orientation setting.
      PORTRAIT                                   = :portrait

      # Definition for a document orientation setting.
      LANDSCAPE                                  = :landscape

      # Definition for a default margin setting.
      DEFAULT_LEFT_MARGIN                        = 1800

      # Definition for a default margin setting.
      DEFAULT_RIGHT_MARGIN                       = 1800

      # Definition for a default margin setting.
      DEFAULT_TOP_MARGIN                         = 1440

      # Definition for a default margin setting.
      DEFAULT_BOTTOM_MARGIN                      = 1440

      # Attribute accessor.
      attr_reader :paper, :left_margin, :right_margin, :top_margin,
                  :bottom_margin, :gutter, :orientation

      # Attribute mutator.
      attr_writer :paper, :left_margin, :right_margin, :top_margin,
                  :bottom_margin, :gutter, :orientation

      # This is a constructor for the DocumentStyle class. This creates a
      # document style with a default paper setting of A4 and portrait
      # orientation (all other attributes are nil).
      def initialize
         @paper         = Paper::A4
         @left_margin   = DEFAULT_LEFT_MARGIN
         @right_margin  = DEFAULT_RIGHT_MARGIN
         @top_margin    = DEFAULT_TOP_MARGIN
         @bottom_margin = DEFAULT_BOTTOM_MARGIN
         @gutter        = nil
         @orientation   = PORTRAIT
      end

      # This method overrides the is_document_style? method inherited from the
      # Style class to always return true.
      def is_document_style?
         true
      end

      # This method generates a string containing the prefix associated with a
      # style object.
      #
      # ==== Parameters
      # document::  A reference to the document using the style.
      def prefix(fonts=nil, colours=nil)
         text = StringIO.new

         if orientation == LANDSCAPE
            text << "\\paperw#{@paper.height}" if @paper != nil
            text << "\\paperh#{@paper.width}" if @paper != nil
         else
            text << "\\paperw#{@paper.width}" if @paper != nil
            text << "\\paperh#{@paper.height}" if @paper != nil
         end
         text << "\\margl#{@left_margin}" if @left_margin != nil
         text << "\\margr#{@right_margin}" if @right_margin != nil
         text << "\\margt#{@top_margin}" if @top_margin != nil
         text << "\\margb#{@bottom_margin}" if @bottom_margin != nil
         text << "\\gutter#{@gutter}" if @gutter != nil
         text << '\sectd\lndscpsxn' if @orientation == LANDSCAPE

         text.string
      end

      # This method fetches the width of the available work area space for a
      # DocumentStyle object.
      def body_width
         if orientation == PORTRAIT
            @paper.width - (@left_margin + @right_margin)
         else
            @paper.height - (@left_margin + @right_margin)
         end
      end

      # This method fetches the height of the available work area space for a
      # DocumentStyle object.
      def body_height
         if orientation == PORTRAIT
            @paper.height - (@top_margin + @bottom_margin)
         else
            @paper.width - (@top_margin + @bottom_margin)
         end
      end
   end # End of the DocumentStyle class.
end # End of the RTF module.