#!/usr/bin/env ruby

require 'stringio'

module RTF
   # This class represents an element within an RTF document. The class provides
   # a base class for more specific node types.
   class Node
      # Attribute accessor.
      attr_reader :parent

      # Attribute mutator.
      attr_writer :parent


      # This is the constructor for the Node class.
      #
      # ==== Parameters
      # parent::  A reference to the Node that owns the new Node. May be nil
      #           to indicate a base or root node.
      def initialize(parent)
         @parent = parent
      end

      # This method retrieves a Node objects previous peer node, returning nil
      # if the Node has no previous peer.
      def previous_node
         peer = nil
         if parent != nil and parent.respond_to?(:children)
            index = parent.children.index(self)
            peer  = index > 0 ? parent.children[index - 1] : nil
         end
         peer
      end

      # This method retrieves a Node objects next peer node, returning nil
      # if the Node has no previous peer.
      def next_node
         peer = nil
         if parent != nil and parent.respond_to?(:children)
            index = parent.children.index(self)
            peer  = parent.children[index + 1]
         end
         peer
      end

      # This method is used to determine whether a Node object represents a
      # root or base element. The method returns true if the Nodes parent is
      # nil, false otherwise.
      def is_root?
         @parent == nil
      end

      # This method traverses a Node tree to locate the root element.
      def root
         node = self
         node = node.parent while node.parent != nil
         node
      end
   end # End of the Node class.


   # This class represents a specialisation of the Node class to refer to a Node
   # that simply contains text.
   class TextNode < Node
      # Attribute accessor.
      attr_reader :text

      # Attribute mutator.
      attr_writer :text

      # This is the constructor for the TextNode class.
      #
      # ==== Parameters
      # parent::  A reference to the Node that owns the TextNode. Must not be
      #           nil.
      # text::    A String containing the node text. Defaults to nil.
      #
      # ==== Exceptions
      # RTFError::  Generated whenever an nil parent object is specified to
      #             the method.
      def initialize(parent, text=nil)
         super(parent)
         if parent == nil
            RTFError.fire("Nil parent specified for text node.")
         end
         @parent = parent
         @text   = text
      end

      # This method concatenates a String on to the end of the existing text
      # within a TextNode object.
      #
      # ==== Parameters
      # text::  The String to be added to the end of the text node.
      def append(text)
         if @text != nil
            @text = @text + text.to_s
         else
            @text = text.to_s
         end
      end

      # This method inserts a String into the existing text within a TextNode
      # object. If the TextNode contains no text then it is simply set to the
      # text passed in. If the offset specified is past the end of the nodes
      # text then it is simply appended to the end.
      #
      # ==== Parameters
      # text::    A String containing the text to be added.
      # offset::  The numbers of characters from the first character to insert
      #           the new text at.
      def insert(text, offset)
         if @text != nil
            @text = @text[0, offset] + text.to_s + @text[offset, @text.length]
         else
            @text = text.to_s
         end
      end

      # This method generates the RTF equivalent for a TextNode object. This
      # method escapes any special sequences that appear in the text.
      def to_rtf
         @text == nil ? '' : @text.gsub("{", "\\{").gsub("}", "\\}").gsub("\\", "\\\\")
      end
   end # End of the TextNode class.


   # This class represents a Node that can contain other Node objects. Its a
   # base class for more specific Node types.
   class ContainerNode < Node
      include Enumerable

      # Attribute accessor.
      attr_reader :children

      # Attribute mutator.
      attr_writer :children

      # This is the constructor for the ContainerNode class.
      #
      # ==== Parameters
      # parent::     A reference to the parent node that owners the new
      #              ContainerNode object.
      def initialize(parent)
         super(parent)
         @children = []
         @children.concat(yield) if block_given?
      end

      # This method adds a new node element to the end of the list of nodes
      # maintained by a ContainerNode object. Nil objects are ignored.
      #
      # ==== Parameters
      # node::  A reference to the Node object to be added.
      def store(node)
         if node != nil
            @children.push(node) if @children.include?(Node) == false
            node.parent = self if node.parent != self
         end
         node
      end

      # This method fetches the first node child for a ContainerNode object. If
      # a container contains no children this method returns nil.
      def first
         @children[0]
      end

      # This method fetches the last node child for a ContainerNode object. If
      # a container contains no children this method returns nil.
      def last
         @children.last
      end

      # This method provides for iteration over the contents of a ContainerNode
      # object.
      def each
         @children.each {|child| yield child}
      end

      # This method returns a count of the number of children a ContainerNode
      # object contains.
      def size
         @children.size
      end

      # This method overloads the array dereference operator to allow for
      # access to the child elements of a ContainerNode object.
      #
      # ==== Parameters
      # index::  The offset from the first child of the child object to be
      #          returned. Negative index values work from the back of the
      #          list of children. An invalid index will cause a nil value
      #          to be returned.
      def [](index)
         @children[index]
      end

      # This method generates the RTF text for a ContainerNode object.
      def to_rtf
         RTFError.fire("#{self.class.name}.to_rtf method not yet implemented.")
      end
   end # End of the ContainerNode class.


   # This class represents a RTF command element within a document. This class
   # is concrete enough to be used on its own but will also be used as the
   # base class for some specific command node types.
   class CommandNode < ContainerNode
      # Attribute accessor.
      attr_reader :prefix, :suffix, :split

      # Attribute mutator.
      attr_writer :prefix, :suffix, :split

      # This is the constructor for the CommandNode class.
      #
      # ==== Parameters
      # parent::  A reference to the node that owns the new node.
      # prefix::  A String containing the prefix text for the command.
      # suffix::  A String containing the suffix text for the command. Defaults
      #           to nil.
      # split::   A boolean to indicate whether the prefix and suffix should
      #           be written to separate lines whether the node is converted
      #           to RTF. Defaults to true.
      def initialize(parent, prefix, suffix=nil, split=true)
         super(parent)
         @prefix = prefix
         @suffix = suffix
         @split  = split
      end

      # This method adds text to a command node. If the last child node of the
      # target node is a TextNode then the text is appended to that. Otherwise
      # a new TextNode is created and append to the node.
      #
      # ==== Parameters
      # text::  The String of text to be written to the node.
      def <<(text)
         if last != nil and last.respond_to?(:text=)
            last.append(text)
         else
            self.store(TextNode.new(self, text))
         end
      end

      # This method generates the RTF text for a CommandNode object.
      def to_rtf
         text      = StringIO.new
         separator = split? ? "\n" : " "
         line      = (separator == " ")

         text << "{#{@prefix}"
         text << separator if self.size > 0
         self.each do |entry|
            text << "\n" if line
            line = true
            text << "#{entry.to_rtf}"
         end
         text << "\n" if split?
         text << "#{@suffix}}"
         text.string
      end

      # This method provides a short cut means of creating a paragraph command
      # node. The method accepts a block that will be passed a single parameter
      # which will be a reference to the paragraph node created. After the
      # block is complete the paragraph node is appended to the end of the child
      # nodes on the object that the method is called against.
      #
      # ==== Parameters
      # style::  A reference to a ParagraphStyle object that defines the style
      #          for the new paragraph. Defaults to nil to indicate that the
      #          currently applied paragraph styling should be used.
      def paragraph(style=nil)
         # Create the node prefix.
         text = StringIO.new
         text << '\pard'
         text << style.prefix(nil, nil) if style != nil

         node = CommandNode.new(self, text.string, '\par')
         yield node if block_given?
         self.store(node)
      end

      # This method provides a short cut means of creating a line break command
      # node. This command node does not take a block and may possess no other
      # content.
      def line_break
         self.store(CommandNode.new(self, '\line', nil, false))
         nil
      end

      # This method inserts a footnote at the current position in a node.
      #
      # ==== Parameters
      # text::  A string containing the text for the footnote.
      def footnote(text)
         if text != nil && text != ''
            mark = CommandNode.new(self, '\fs16\up6\chftn', nil, false)
            note = CommandNode.new(self, '\footnote {\fs16\up6\chftn}', nil, false)
            note.paragraph << text
            self.store(mark)
            self.store(note)
         end
      end

      # This method provides a short cut means for applying multiple styles via
      # single command node. The method accepts a block that will be passed a
      # reference to the node created. Once the block is complete the new node
      # will be append as the last child of the CommandNode the method is called
      # on.
      #
      # ==== Parameters
      # style::  A reference to a CharacterStyle object that contains the style
      #          settings to be applied.
      #
      # ==== Exceptions
      # RTFError::  Generated whenever a non-character style is specified to
      #             the method.
      def apply(style)
         # Check the input style.
         if style.is_character_style? == false
            RTFError.fire("Non-character style specified to the "\
                          "CommandNode#apply() method.")
         end

         # Store fonts and colours.
         root.colours << style.foreground if style.foreground != nil
         root.colours << style.background if style.background != nil
         root.fonts << style.font if style.font != nil

         # Generate the command node.
         node = CommandNode.new(self, style.prefix(root.fonts, root.colours))
         yield node if block_given?
         self.store(node)
      end

      # This method provides a short cut means of creating a bold command node.
      # The method accepts a block that will be passed a single parameter which
      # will be a reference to the bold node created. After the block is
      # complete the bold node is appended to the end of the child nodes on
      # the object that the method is call against.
      def bold
         style      = CharacterStyle.new
         style.bold = true
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut means of creating an italic command
      # node. The method accepts a block that will be passed a single parameter
      # which will be a reference to the italic node created. After the block is
      # complete the italic node is appended to the end of the child nodes on
      # the object that the method is call against.
      def italic
         style        = CharacterStyle.new
         style.italic = true
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut means of creating an underline command
      # node. The method accepts a block that will be passed a single parameter
      # which will be a reference to the underline node created. After the block
      # is complete the underline node is appended to the end of the child nodes
      # on the object that the method is call against.
      def underline
         style           = CharacterStyle.new
         style.underline = true
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut means of creating a superscript command
      # node. The method accepts a block that will be passed a single parameter
      # which will be a reference to the superscript node created. After the
      # block is complete the superscript node is appended to the end of the
      # child nodes on the object that the method is call against.
      def superscript
         style             = CharacterStyle.new
         style.superscript = true
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut means of creating a font command node.
      # The method accepts a block that will be passed a single parameter which
      # will be a reference to the font node created. After the block is
      # complete the font node is appended to the end of the child nodes on the
      # object that the method is called against.
      #
      # ==== Parameters
      # font::  A reference to font object that represents the font to be used
      #         within the node.
      # size::  An integer size setting for the font. Defaults to nil to
      #         indicate that the current font size should be used.
      def font(font, size=nil)
         style           = CharacterStyle.new
         style.font      = font
         style.font_size = size
         root.fonts << font
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut means of creating a foreground colour
      # command node. The method accepts a block that will be passed a single
      # parameter which will be a reference to the foreground colour node
      # created. After the block is complete the foreground colour node is
      # appended to the end of the child nodes on the object that the method
      # is called against.
      #
      # ==== Parameters
      # colour::  The foreground colour to be applied by the command.
      def foreground(colour)
         style            = CharacterStyle.new
         style.foreground = colour
         root.colours << colour
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut means of creating a background colour
      # command node. The method accepts a block that will be passed a single
      # parameter which will be a reference to the background colour node
      # created. After the block is complete the background colour node is
      # appended to the end of the child nodes on the object that the method
      # is called against.
      #
      # ==== Parameters
      # colour::  The background colour to be applied by the command.
      def background(colour)
         style            = CharacterStyle.new
         style.background = colour
         root.colours << colour
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method provides a short cut menas of creating a colour node that
      # deals with foreground and background colours. The method accepts a
      # block that will be passed a single parameter which will be a reference
      # to the colour node created. After the block is complete the colour node
      # is append to the end of the child nodes on the object that the method
      # is called against.
      #
      # ==== Parameters
      # fore::  The foreground colour to be applied by the command.
      # back::  The background colour to be applied by the command.
      def colour(fore, back)
         style            = CharacterStyle.new
         style.foreground = fore
         style.background = back
         root.colours << fore
         root.colours << back
         if block_given?
            apply(style) {|node| yield node}
         else
            apply(style)
         end
      end

      # This method creates a new table node and returns it. The method accepts
      # a block that will be passed the table as a parameter. The node is added
      # to the node the method is called upon after the block is complete.
      #
      # ==== Parameters
      # rows::     The number of rows that the table contains.
      # columns::  The number of columns that the table contains.
      # *widths::  One or more integers representing the widths for the table
      #            columns.
      def table(rows, columns, *widths)
         node = TableNode.new(self, rows, columns, *widths)
         yield node if block_given?
         store(node)
         node
      end

      alias :write :<<
      alias :color :colour
      alias :split? :split
   end # End of the CommandNode class.


   # This class represents a table node within an RTF document. Table nodes are
   # specialised container nodes that contain only TableRowNodes and have their
   # size specified when they are created an cannot be resized after that.
   class TableNode < ContainerNode
      # Attribute accessor.
      attr_reader :cell_margin

      # Attribute mutator.
      attr_writer :cell_margin

      # This is a constructor for the TableNode class.
      #
      # ==== Parameters
      # parent::   A reference to the node that owns the table.
      # rows::     The number of rows in the tabkle.
      # columns::  The number of columns in the table.
      # *widths::  One or more integers specifying the widths of the table
      #            columns.
      def initialize(parent, rows, columns, *widths)
         super(parent) do
            entries = []
            rows.times {entries.push(TableRowNode.new(self, columns, *widths))}
            entries
         end
         @cell_margin = 100
      end

      # Attribute accessor.
      def rows
         entries.size
      end

      # Attribute accessor.
      def columns
         entries[0].length
      end

      # This method assigns a border width setting to all of the sides on all
      # of the cells within a table.
      #
      # ==== Parameters
      # width::  The border width setting to apply. Negative values are ignored
      #          and zero switches the border off.
      def border_width=(width)
         self.each {|row| row.border_width = width}
      end

      # This method assigns a shading colour to a specified row within a
      # TableNode object.
      #
      # ==== Parameters
      # index::   The offset from the first row of the row to have shading
      #           applied to it.
      # colour::  A reference to a Colour object representing the shading colour
      #           to be used. Set to nil to clear shading.
      def row_shading_colour(index, colour)
         row = self[index]
         row.shading_colour = colour if row != nil
      end

      # This method assigns a shading colour to a specified column within a
      # TableNode object.
      #
      # ==== Parameters
      # index::   The offset from the first column of the column to have shading
      #           applied to it.
      # colour::  A reference to a Colour object representing the shading colour
      #           to be used. Set to nil to clear shading.
      def column_shading_colour(index, colour)
         self.each do |row|
            cell = row[index]
            cell.shading_colour = colour if cell != nil
         end
      end

      # This method provides a means of assigning a shading colour to a
      # selection of cells within a table. The method accepts a block that
      # takes three parameters - a TableCellNode representing a cell within the
      # table, an integer representing the x offset of the cell and an integer
      # representing the y offset of the cell. If the block returns true then
      # shading will be applied to the cell.
      #
      # ==== Parameters
      # colour::  A reference to a Colour object representing the shading colour
      #           to be applied. Set to nil to remove shading.
      def shading_colour(colour)
         if block_given?
            0.upto(self.size - 1) do |x|
               row = self[x]
               0.upto(row.size - 1) do |y|
                  apply = yield row[y], x, y
                  row[y].shading_colour = colour if apply
               end
            end
         end
      end

      # This method overloads the store method inherited from the ContainerNode
      # class to forbid addition of further nodes.
      #
      # ==== Parameters
      # node::  A reference to the node to be added.
      def store(node)
         RTFError.fire("Table nodes cannot have nodes added to.")
      end

      # This method generates the RTF document text for a TableCellNode object.
      def to_rtf
         text = StringIO.new
         size = 0

         self.each do |row|
            if size > 0
               text << "\n"
            else
               size = 1
            end
            text << row.to_rtf
         end

         text.string
      end

      alias :column_shading_color :column_shading_colour
      alias :row_shading_color :row_shading_colour
      alias :shading_color :shading_colour
   end # End of the TableNode class.


   # This class represents a row within an RTF table. The TableRowNode is a
   # specialised container node that can hold only TableCellNodes and, once
   # created, cannot be resized. Its also not possible to change the parent
   # of a TableRowNode object.
   class TableRowNode < ContainerNode
      # This is the constructor for the TableRowNode class.
      #
      # ===== Parameters
      # table::   A reference to table that owns the row.
      # cells::   The number of cells that the row will contain.
      # widths::  One or more integers specifying the widths for the table
      #           columns
      def initialize(table, cells, *widths)
         super(table) do
            entries = []
            cells.times do |index|
               entries.push(TableCellNode.new(self, widths[index]))
            end
            entries
         end
      end

      # Attrobute accessors
      def length
         entries.size
      end

      # This method assigns a border width setting to all of the sides on all
      # of the cells within a table row.
      #
      # ==== Parameters
      # width::  The border width setting to apply. Negative values are ignored
      #          and zero switches the border off.
      def border_width=(width)
         self.each {|cell| cell.border_width = width}
      end

      # This method overloads the parent= method inherited from the Node class
      # to forbid the alteration of the cells parent.
      #
      # ==== Parameters
      # parent::  A reference to the new node parent.
      def parent=(parent)
         RTFError.fire("Table row nodes cannot have their parent changed.")
      end

      # This method sets the shading colour for a row.
      #
      # ==== Parameters
      # colour::  A reference to the Colour object that represents the new
      #           shading colour. Set to nil to switch shading off.
      def shading_colour=(colour)
         self.each {|cell| cell.shading_colour = colour}
      end

      # This method overloads the store method inherited from the ContainerNode
      # class to forbid addition of further nodes.
      #
      # ==== Parameters
      # node::  A reference to the node to be added.
      #def store(node)
      #   RTFError.fire("Table row nodes cannot have nodes added to.")
      #end

      # This method generates the RTF document text for a TableCellNode object.
      def to_rtf
         text   = StringIO.new
         temp   = StringIO.new
         offset = 0

         text << "\\trowd\\tgraph#{parent.cell_margin}"
         self.each do |entry|
            widths = entry.border_widths
            colour = entry.shading_colour

            text << "\n"
            text << "\\clbrdrt\\brdrw#{widths[0]}\\brdrs" if widths[0] != 0
            text << "\\clbrdrl\\brdrw#{widths[3]}\\brdrs" if widths[3] != 0
            text << "\\clbrdrb\\brdrw#{widths[2]}\\brdrs" if widths[2] != 0
            text << "\\clbrdrr\\brdrw#{widths[1]}\\brdrs" if widths[1] != 0
            text << "\\clcbpat#{root.colours.index(colour)}" if colour != nil
            text << "\\cellx#{entry.width + offset}"
            temp << "\n#{entry.to_rtf}"
            offset += entry.width
         end
         text << "#{temp.string}\n\\row"

         text.string
      end
   end # End of the TableRowNode class.


   # This class represents a cell within an RTF table. The TableCellNode is a
   # specialised command node that is forbidden from creating tables or having
   # its parent changed.
   class TableCellNode < CommandNode
      # A definition for the default width for the cell.
      DEFAULT_WIDTH                              = 300

      # Attribute accessor.
      attr_reader :width, :shading_colour, :style

      # Attribute mutator.
      attr_writer :width, :style

      # This is the constructor for the TableCellNode class.
      #
      # ==== Parameters
      # row::     The row that the cell belongs to.
      # width::   The width to be assigned to the cell. This defaults to
      #           TableCellNode::DEFAULT_WIDTH.
      # style::   The style that is applied to the cell. This must be a
      #           ParagraphStyle class. Defaults to nil.
      # top::     The border width for the cells top border. Defaults to nil.
      # right::   The border width for the cells right hand border. Defaults to
      #           nil.
      # bottom::  The border width for the cells bottom border. Defaults to nil.
      # left::    The border width for the cells left hand border. Defaults to
      #           nil.
      #
      # ==== Exceptions
      # RTFError::  Generated whenever an invalid style setting is specified.
      def initialize(row, width=DEFAULT_WIDTH, style=nil, top=nil, right=nil,
                     bottom=nil, left=nil)
         super(row, nil)
         if style != nil && style.is_paragraph_style? == false
            RTFError.fire("Non-paragraph style specified for TableCellNode "\
                          "constructor.")
         end

         @width          = (width != nil && width > 0) ? width : DEFAULT_WIDTH
         @borders        = [(top != nil && top > 0) ? top : nil,
                            (right != nil && right > 0) ? right : nil,
                            (bottom != nil && bottom > 0) ? bottom : nil,
                            (left != nil && left > 0) ? left : nil]
         @shading_colour = nil
         @style          = style
      end

      # Attribute mutator.
      #
      # ==== Parameters
      # style::  A reference to the style object to be applied to the cell.
      #          Must be an instance of the ParagraphStyle class. Set to nil
      #          to clear style settings.
      #
      # ==== Exceptions
      # RTFError::  Generated whenever an invalid style setting is specified.
      def style=(style)
         if style != nil && style.is_paragraph_style? == false
            RTFError.fire("Non-paragraph style specified for TableCellNode "\
                          "constructor.")
         end
         @style = style
      end

      # This method assigns a width, in twips, for the borders on all sides of
      # the cell. Negative widths will be ignored and a width of zero will
      # switch the border off.
      #
      # ==== Parameters
      # width::  The setting for the width of the border.
      def border_width=(width)
         size = width == nil ? 0 : width
         if size > 0
            @borders[0] = @borders[1] = @borders[2] = @borders[3] = size.to_i
         else
            @borders = [nil, nil, nil, nil]
         end
      end

      # This method assigns a border width to the top side of a table cell.
      # Negative values are ignored and a value of 0 switches the border off.
      #
      # ==== Parameters
      # width::  The new border width setting.
      def top_border_width=(width)
         size = width == nil ? 0 : width
         if size > 0
            @borders[0] = size.to_i
         else
            @borders[0] = nil
         end
      end

      # This method assigns a border width to the right side of a table cell.
      # Negative values are ignored and a value of 0 switches the border off.
      #
      # ==== Parameters
      # width::  The new border width setting.
      def right_border_width=(width)
         size = width == nil ? 0 : width
         if size > 0
            @borders[1] = size.to_i
         else
            @borders[1] = nil
         end
      end

      # This method assigns a border width to the bottom side of a table cell.
      # Negative values are ignored and a value of 0 switches the border off.
      #
      # ==== Parameters
      # width::  The new border width setting.
      def bottom_border_width=(width)
         size = width == nil ? 0 : width
         if size > 0
            @borders[2] = size.to_i
         else
            @borders[2] = nil
         end
      end

      # This method assigns a border width to the left side of a table cell.
      # Negative values are ignored and a value of 0 switches the border off.
      #
      # ==== Parameters
      # width::  The new border width setting.
      def left_border_width=(width)
         size = width == nil ? 0 : width
         if size > 0
            @borders[3] = size.to_i
         else
            @borders[3] = nil
         end
      end

      # This method alters the shading colour associated with a TableCellNode
      # object.
      #
      # ==== Parameters
      # colour::  A reference to the Colour object to use in shading the cell.
      #           Assign nil to clear cell shading.
      def shading_colour=(colour)
         root.colours << colour
         @shading_colour = colour
      end

      # This method retrieves an array with the cell border width settings.
      # The values are inserted in top, right, bottom, left order.
      def border_widths
         widths = []
         @borders.each {|entry| widths.push(entry == nil ? 0 : entry)}
         widths
      end

      # This method fetches the width for top border of a cell.
      def top_border_width
         @borders[0] == nil ? 0 : @borders[0]
      end

      # This method fetches the width for right border of a cell.
      def right_border_width
         @borders[1] == nil ? 0 : @borders[1]
      end

      # This method fetches the width for bottom border of a cell.
      def bottom_border_width
         @borders[2] == nil ? 0 : @borders[2]
      end

      # This method fetches the width for left border of a cell.
      def left_border_width
         @borders[3] == nil ? 0 : @borders[3]
      end

      # This method overloads the paragraph method inherited from the
      # ComamndNode class to forbid the creation of paragraphs.
      #
      # ==== Parameters
      # justification::  The justification to be applied to the paragraph.
      # before::         The amount of space, in twips, to be inserted before
      #                  the paragraph. Defaults to nil.
      # after::          The amount of space, in twips, to be inserted after
      #                  the paragraph. Defaults to nil.
      # left::           The amount of indentation to place on the left of the
      #                  paragraph. Defaults to nil.
      # right::          The amount of indentation to place on the right of the
      #                  paragraph. Defaults to nil.
      # first::          The amount of indentation to place on the left of the
      #                  first line in the paragraph. Defaults to nil.
      def paragraph(justification=CommandNode::LEFT_JUSTIFY, before=nil,
                    after=nil, left=nil, right=nil, first=nil)
         RTFError.fire("TableCellNode#paragraph() called. Table cells cannot "\
                       "contain paragraphs.")
      end

      # This method overloads the parent= method inherited from the Node class
      # to forbid the alteration of the cells parent.
      #
      # ==== Parameters
      # parent::  A reference to the new node parent.
      def parent=(parent)
         RTFError.fire("Table cell nodes cannot have their parent changed.")
      end

      # This method overrides the table method inherited from CommandNode to
      # forbid its use in table cells.
      #
      # ==== Parameters
      # rows::     The number of rows for the table.
      # columns::  The number of columns for the table.
      # *widths::  One or more integers representing the widths for the table
      #            columns.
      def table(rows, columns, *widths)
         RTFError.fire("TableCellNode#table() called. Nested tables not allowed.")
      end

      # This method generates the RTF document text for a TableCellNode object.
      def to_rtf
         text      = StringIO.new
         separator = split? ? "\n" : " "
         line      = (separator == " ")

         text << "\\pard\\intbl"
         text << @style.prefix(nil, nil) if @style != nil
         text << separator
         self.each do |entry|
            text << "\n" if line
            line = true
            text << entry.to_rtf
         end
         text << (split? ? "\n" : " ")
         text << "\\cell"

         text.string
      end
   end # End of the TableCellNode class.


   # This class represents a document header.
   class HeaderNode < CommandNode
      # A definition for a header type.
      UNIVERSAL                                  = :header

      # A definition for a header type.
      LEFT_PAGE                                  = :headerl

      # A definition for a header type.
      RIGHT_PAGE                                 = :headerr

      # A definition for a header type.
      FIRST_PAGE                                 = :headerf

      # Attribute accessor.
      attr_reader :type

      # Attribute mutator.
      attr_writer :type


      # This is the constructor for the HeaderNode class.
      #
      # ==== Parameters
      # document::  A reference to the Document object that will own the new
      #             header.
      # type::      The style type for the new header. Defaults to a value of
      #             HeaderNode::UNIVERSAL.
      def initialize(document, type=UNIVERSAL)
         super(document, "\\#{type.id2name}", nil, false)
         @type = type
      end

      # This method overloads the footnote method inherited from the CommandNode
      # class to prevent footnotes being added to headers.
      #
      # ==== Parameters
      # text::  Not used.
      #
      # ==== Exceptions
      # RTFError::  Always generated whenever this method is called.
      def footnote(text)
         RTFError.fire("Footnotes are not permitted in page headers.")
      end
   end # End of the HeaderNode class.


   # This class represents a document footer.
   class FooterNode < CommandNode
      # A definition for a header type.
      UNIVERSAL                                  = :footer

      # A definition for a header type.
      LEFT_PAGE                                  = :footerl

      # A definition for a header type.
      RIGHT_PAGE                                 = :footerr

      # A definition for a header type.
      FIRST_PAGE                                 = :footerf

      # Attribute accessor.
      attr_reader :type

      # Attribute mutator.
      attr_writer :type


      # This is the constructor for the FooterNode class.
      #
      # ==== Parameters
      # document::  A reference to the Document object that will own the new
      #             footer.
      # type::      The style type for the new footer. Defaults to a value of
      #             FooterNode::UNIVERSAL.
      def initialize(document, type=UNIVERSAL)
         super(document, "\\#{type.id2name}", nil, false)
         @type = type
      end

      # This method overloads the footnote method inherited from the CommandNode
      # class to prevent footnotes being added to footers.
      #
      # ==== Parameters
      # text::  Not used.
      #
      # ==== Exceptions
      # RTFError::  Always generated whenever this method is called.
      def footnote(text)
         RTFError.fire("Footnotes are not permitted in page footers.")
      end
   end # End of the FooterNode class.


   # This class represents an RTF document. In actuality it is just a
   # specialised Node type that cannot be assigned a parent and that holds
   # document font, colour and information tables.
   class Document < CommandNode
      # A definition for a document character set setting.
      CS_ANSI                          = :ansi

      # A definition for a document character set setting.
      CS_MAC                           = :mac

      # A definition for a document character set setting.
      CS_PC                            = :pc

      # A definition for a document character set setting.
      CS_PCA                           = :pca

      # A definition for a document language setting.
      LC_AFRIKAANS                     = 1078

      # A definition for a document language setting.
      LC_ARABIC                        = 1025

      # A definition for a document language setting.
      LC_CATALAN                       = 1027

      # A definition for a document language setting.
      LC_CHINESE_TRADITIONAL           = 1028

      # A definition for a document language setting.
      LC_CHINESE_SIMPLIFIED            = 2052

      # A definition for a document language setting.
      LC_CZECH                         = 1029

      # A definition for a document language setting.
      LC_DANISH                        = 1030

      # A definition for a document language setting.
      LC_DUTCH                         = 1043

      # A definition for a document language setting.
      LC_DUTCH_BELGIAN                 = 2067

      # A definition for a document language setting.
      LC_ENGLISH_UK                    = 2057

      # A definition for a document language setting.
      LC_ENGLISH_US                    = 1033

      # A definition for a document language setting.
      LC_FINNISH                       = 1035

      # A definition for a document language setting.
      LC_FRENCH                        = 1036

      # A definition for a document language setting.
      LC_FRENCH_BELGIAN                = 2060

      # A definition for a document language setting.
      LC_FRENCH_CANADIAN               = 3084

      # A definition for a document language setting.
      LC_FRENCH_SWISS                  = 4108

      # A definition for a document language setting.
      LC_GERMAN                        = 1031

      # A definition for a document language setting.
      LC_GERMAN_SWISS                  = 2055

      # A definition for a document language setting.
      LC_GREEK                         = 1032

      # A definition for a document language setting.
      LC_HEBREW                        = 1037

      # A definition for a document language setting.
      LC_HUNGARIAN                     = 1038

      # A definition for a document language setting.
      LC_ICELANDIC                     = 1039

      # A definition for a document language setting.
      LC_INDONESIAN                    = 1057

      # A definition for a document language setting.
      LC_ITALIAN                       = 1040

      # A definition for a document language setting.
      LC_JAPANESE                      = 1041

      # A definition for a document language setting.
      LC_KOREAN                        = 1042

      # A definition for a document language setting.
      LC_NORWEGIAN_BOKMAL              = 1044

      # A definition for a document language setting.
      LC_NORWEGIAN_NYNORSK             = 2068

      # A definition for a document language setting.
      LC_POLISH                        = 1045

      # A definition for a document language setting.
      LC_PORTUGUESE                    = 2070

      # A definition for a document language setting.
      LC_POTUGUESE_BRAZILIAN           = 1046

      # A definition for a document language setting.
      LC_ROMANIAN                      = 1048

      # A definition for a document language setting.
      LC_RUSSIAN                       = 1049

      # A definition for a document language setting.
      LC_SERBO_CROATIAN_CYRILLIC       = 2074

      # A definition for a document language setting.
      LC_SERBO_CROATIAN_LATIN          = 1050

      # A definition for a document language setting.
      LC_SLOVAK                        = 1051

      # A definition for a document language setting.
      LC_SPANISH_CASTILLIAN            = 1034

      # A definition for a document language setting.
      LC_SPANISH_MEXICAN               = 2058

      # A definition for a document language setting.
      LC_SWAHILI                       = 1089

      # A definition for a document language setting.
      LC_SWEDISH                       = 1053

      # A definition for a document language setting.
      LC_THAI                          = 1054

      # A definition for a document language setting.
      LC_TURKISH                       = 1055

      # A definition for a document language setting.
      LC_UNKNOWN                       = 1024

      # A definition for a document language setting.
      LC_VIETNAMESE                    = 1066

      # ASCII equivalents of unicode special characters.  This should cover
      # almost everything that actually has ASCII equialents -- HTML codes
      # "&#1;" to "&#400;".  Feel free to change the mapping.  Is there a way
      # to give multi-character equivalents in the '\uNNNx' directive?
      ASCII_EQUIVALENTS = {
         "\xE2\x82\xAC" => '$',  # €
         "\xEF\xBF\xBD" => '?',  # �
         "\xE2\x80\x9A" => ',',  # ‚
         "\xC6\x92"     => 'f',  # ƒ
         "\xE2\x80\x9E" => '"',  # „
         "\xE2\x80\xA6" => '.',  # …
         "\xE2\x80\xA0" => '+',  # †
         "\xE2\x80\xA1" => '+',  # ‡
         "\xCB\x86"     => '^',  # ˆ
         "\xE2\x80\xB0" => '%',  # ‰
         "\xC5\xA0"     => 'S',  # Š
         "\xE2\x80\xB9" => '<',  # ‹
         "\xC5\x92"     => 'O',  # Œ
         "\xEF\xBF\xBD" => '?',  # �
         "\xC5\xBD"     => 'Z',  # Ž
         "\xEF\xBF\xBD" => '?',  # �
         "\xEF\xBF\xBD" => '?',  # �
         "\xE2\x80\x98" => "'",  # ‘
         "\xE2\x80\x99" => "'",  # ’
         "\xE2\x80\x9C" => '"',  # “
         "\xE2\x80\x9D" => '"',  # ”
         "\xE2\x80\xA2" => '.',  # •
         "\xE2\x80\x93" => '-',  # –
         "\xE2\x80\x94" => '-',  # —
         "\xCB\x9C"     => '~',  # ˜
         "\xE2\x84\xA2" => '?',  # ™
         "\xC5\xA1"     => 'S',  # š
         "\xE2\x80\xBA" => '>',  # ›
         "\xC5\x93"     => 'o',  # œ
         "\xEF\xBF\xBD" => '?',  # �
         "\xC5\xBE"     => 'Z',  # ž
         "\xC5\xB8"     => 'Y',  # Ÿ
         "\xC2\xA1"     => '!',  # ¡
         "\xC2\xA2"     => '$',  # ¢
         "\xC2\xA3"     => '$',  # £
         "\xC2\xA4"     => '$',  # ¤
         "\xC2\xA5"     => '$',  # ¥
         "\xC2\xA6"     => '|',  # ¦
         "\xC2\xA7"     => '?',  # §
         "\xC2\xA8"     => '?',  # ¨
         "\xC2\xA9"     => '?',  # ©
         "\xC2\xAA"     => 'a',  # ª
         "\xC2\xAB"     => '<',  # «
         "\xC2\xAC"     => '-',  # ¬
         "\xC2\xAD"     => '-',  # ­
         "\xC2\xAE"     => '?',  # ®
         "\xC2\xAF"     => '-',  # ¯
         "\xC2\xB0"     => 'o',  # °
         "\xC2\xB1"     => '?',  # ±
         "\xC2\xB2"     => '2',  # ²
         "\xC2\xB3"     => '3',  # ³
         "\xC2\xB4"     => "'",  # ´
         "\xC2\xB5"     => 'u',  # µ
         "\xC2\xB6"     => '?',  # ¶
         "\xC2\xB7"     => '.',  # ·
         "\xC2\xB8"     => '.',  # ¸
         "\xC2\xB9"     => '1',  # ¹
         "\xC2\xBA"     => '0',  # º
         "\xC2\xBB"     => '>>', # »
         "\xC2\xBC"     => '?',  # ¼
         "\xC2\xBD"     => '?',  # ½
         "\xC2\xBE"     => '?',  # ¾
         "\xC2\xBF"     => '?',  # ¿
         "\xC3\x80"     => 'A',  # À
         "\xC3\x81"     => 'A',  # Á
         "\xC3\x82"     => 'A',  # Â
         "\xC3\x83"     => 'A',  # Ã
         "\xC3\x84"     => 'A',  # Ä
         "\xC3\x85"     => 'A',  # Å
         "\xC3\x86"     => 'A',  # Æ
         "\xC3\x87"     => 'C',  # Ç
         "\xC3\x88"     => 'E',  # È
         "\xC3\x89"     => 'E',  # É
         "\xC3\x8A"     => 'E',  # Ê
         "\xC3\x8B"     => 'E',  # Ë
         "\xC3\x8C"     => 'I',  # Ì
         "\xC3\x8D"     => 'I',  # Í
         "\xC3\x8E"     => 'I',  # Î
         "\xC3\x8F"     => 'I',  # Ï
         "\xC3\x90"     => 'D',  # Ð
         "\xC3\x91"     => 'N',  # Ñ
         "\xC3\x92"     => 'O',  # Ò
         "\xC3\x93"     => 'O',  # Ó
         "\xC3\x94"     => 'O',  # Ô
         "\xC3\x95"     => 'O',  # Õ
         "\xC3\x96"     => 'O',  # Ö
         "\xC3\x97"     => 'x',  # ×
         "\xC3\x98"     => 'O',  # Ø
         "\xC3\x99"     => 'U',  # Ù
         "\xC3\x9A"     => 'U',  # Ú
         "\xC3\x9B"     => 'U',  # Û
         "\xC3\x9C"     => 'U',  # Ü
         "\xC3\x9D"     => 'Y',  # Ý
         "\xC3\x9E"     => 'P',  # Þ
         "\xC3\x9F"     => 'B',  # ß
         "\xC3\xA0"     => 'a',  # à
         "\xC3\xA1"     => 'a',  # á
         "\xC3\xA2"     => 'a',  # â
         "\xC3\xA3"     => 'a',  # ã
         "\xC3\xA4"     => 'a',  # ä
         "\xC3\xA5"     => 'a',  # å
         "\xC3\xA6"     => 'a',  # æ
         "\xC3\xA7"     => 'c',  # ç
         "\xC3\xA8"     => 'e',  # è
         "\xC3\xA9"     => 'e',  # é
         "\xC3\xAA"     => 'e',  # ê
         "\xC3\xAB"     => 'e',  # ë
         "\xC3\xAC"     => 'i',  # ì
         "\xC3\xAD"     => 'i',  # í
         "\xC3\xAE"     => 'i',  # î
         "\xC3\xAF"     => 'i',  # ï
         "\xC3\xB0"     => 'o',  # ð
         "\xC3\xB1"     => 'n',  # ñ
         "\xC3\xB2"     => 'o',  # ò
         "\xC3\xB3"     => 'o',  # ó
         "\xC3\xB4"     => 'o',  # ô
         "\xC3\xB5"     => 'o',  # õ
         "\xC3\xB6"     => 'o',  # ö
         "\xC3\xB7"     => '/',  # ÷
         "\xC3\xB8"     => 'o',  # ø
         "\xC3\xB9"     => 'u',  # ù
         "\xC3\xBA"     => 'u',  # ú
         "\xC3\xBB"     => 'u',  # û
         "\xC3\xBC"     => 'u',  # ü
         "\xC3\xBD"     => 'y',  # ý
         "\xC3\xBE"     => 'p',  # þ
         "\xC3\xBF"     => 'y',  # ÿ
         "\xC4\x80"     => 'A',  # Ā
         "\xC4\x81"     => 'a',  # ā
         "\xC4\x82"     => 'A',  # Ă
         "\xC4\x83"     => 'a',  # ă
         "\xC4\x84"     => 'A',  # Ą
         "\xC4\x85"     => 'a',  # ą
         "\xC4\x86"     => 'C',  # Ć
         "\xC4\x87"     => 'c',  # ć
         "\xC4\x88"     => 'C',  # Ĉ
         "\xC4\x89"     => 'c',  # ĉ
         "\xC4\x8A"     => 'C',  # Ċ
         "\xC4\x8B"     => 'c',  # ċ
         "\xC4\x8C"     => 'C',  # Č
         "\xC4\x8D"     => 'c',  # č
         "\xC4\x8E"     => 'D',  # Ď
         "\xC4\x8F"     => 'd',  # ď
         "\xC4\x90"     => 'D',  # Đ
         "\xC4\x91"     => 'd',  # đ
         "\xC4\x92"     => 'E',  # Ē
         "\xC4\x93"     => 'e',  # ē
         "\xC4\x94"     => 'E',  # Ĕ
         "\xC4\x95"     => 'e',  # ĕ
         "\xC4\x96"     => 'E',  # Ė
         "\xC4\x97"     => 'e',  # ė
         "\xC4\x98"     => 'E',  # Ę
         "\xC4\x99"     => 'e',  # ę
         "\xC4\x9A"     => 'E',  # Ě
         "\xC4\x9B"     => 'e',  # ě
         "\xC4\x9C"     => 'G',  # Ĝ
         "\xC4\x9D"     => 'g',  # ĝ
         "\xC4\x9E"     => 'G',  # Ğ
         "\xC4\x9F"     => 'g',  # ğ
         "\xC4\xA0"     => 'G',  # Ġ
         "\xC4\xA1"     => 'g',  # ġ
         "\xC4\xA2"     => 'G',  # Ģ
         "\xC4\xA3"     => 'g',  # ģ
         "\xC4\xA4"     => 'H',  # Ĥ
         "\xC4\xA5"     => 'h',  # ĥ
         "\xC4\xA6"     => 'H',  # Ħ
         "\xC4\xA7"     => 'h',  # ħ
         "\xC4\xA8"     => 'I',  # Ĩ
         "\xC4\xA9"     => 'i',  # ĩ
         "\xC4\xAA"     => 'I',  # Ī
         "\xC4\xAB"     => 'i',  # ī
         "\xC4\xAC"     => 'I',  # Ĭ
         "\xC4\xAD"     => 'i',  # ĭ
         "\xC4\xAE"     => 'I',  # Į
         "\xC4\xAF"     => 'i',  # į
         "\xC4\xB0"     => 'I',  # İ
         "\xC4\xB1"     => 'i',  # ı
         "\xC4\xB2"     => 'I',  # Ĳ
         "\xC4\xB3"     => 'i',  # ĳ
         "\xC4\xB4"     => 'J',  # Ĵ
         "\xC4\xB5"     => 'j',  # ĵ
         "\xC4\xB6"     => 'K',  # Ķ
         "\xC4\xB7"     => 'k',  # ķ
         "\xC4\xB8"     => 'k',  # ĸ
         "\xC4\xB9"     => 'L',  # Ĺ
         "\xC4\xBA"     => 'l',  # ĺ
         "\xC4\xBB"     => 'L',  # Ļ
         "\xC4\xBC"     => 'l',  # ļ
         "\xC4\xBD"     => 'L',  # Ľ
         "\xC4\xBE"     => 'l',  # ľ
         "\xC4\xBF"     => 'L',  # Ŀ
         "\xC5\x80"     => 'l',  # ŀ
         "\xC5\x81"     => 'L',  # Ł
         "\xC5\x82"     => 'l',  # ł
         "\xC5\x83"     => 'N',  # Ń
         "\xC5\x84"     => 'n',  # ń
         "\xC5\x85"     => 'N',  # Ņ
         "\xC5\x86"     => 'n',  # ņ
         "\xC5\x87"     => 'N',  # Ň
         "\xC5\x88"     => 'n',  # ň
         "\xC5\x89"     => 'n',  # ŉ
         "\xC5\x8A"     => 'N',  # Ŋ
         "\xC5\x8B"     => 'n',  # ŋ
         "\xC5\x8C"     => 'O',  # Ō
         "\xC5\x8D"     => 'o',  # ō
         "\xC5\x8E"     => 'O',  # Ŏ
         "\xC5\x8F"     => 'o',  # ŏ
         "\xC5\x90"     => 'O',  # Ő
         "\xC5\x91"     => 'o',  # ő
         "\xC5\x92"     => 'O',  # Œ
         "\xC5\x93"     => 'o',  # œ
         "\xC5\x94"     => 'R',  # Ŕ
         "\xC5\x95"     => 'r',  # ŕ
         "\xC5\x96"     => 'R',  # Ŗ
         "\xC5\x97"     => 'r',  # ŗ
         "\xC5\x98"     => 'R',  # Ř
         "\xC5\x99"     => 'r',  # ř
         "\xC5\x9A"     => 'S',  # Ś
         "\xC5\x9B"     => 's',  # ś
         "\xC5\x9C"     => 'S',  # Ŝ
         "\xC5\x9D"     => 's',  # ŝ
         "\xC5\x9E"     => 'S',  # Ş
         "\xC5\x9F"     => 's',  # ş
         "\xC5\xA0"     => 'S',  # Š
         "\xC5\xA1"     => 's',  # š
         "\xC5\xA2"     => 'T',  # Ţ
         "\xC5\xA3"     => 't',  # ţ
         "\xC5\xA4"     => 'T',  # Ť
         "\xC5\xA5"     => 't',  # ť
         "\xC5\xA6"     => 'T',  # Ŧ
         "\xC5\xA7"     => 't',  # ŧ
         "\xC5\xA8"     => 'U',  # Ũ
         "\xC5\xA9"     => 'u',  # ũ
         "\xC5\xAA"     => 'U',  # Ū
         "\xC5\xAB"     => 'u',  # ū
         "\xC5\xAC"     => 'U',  # Ŭ
         "\xC5\xAD"     => 'u',  # ŭ
         "\xC5\xAE"     => 'U',  # Ů
         "\xC5\xAF"     => 'u',  # ů
         "\xC5\xB0"     => 'U',  # Ű
         "\xC5\xB1"     => 'u',  # ű
         "\xC5\xB2"     => 'U',  # Ų
         "\xC5\xB3"     => 'u',  # ų
         "\xC5\xB4"     => 'W',  # Ŵ
         "\xC5\xB5"     => 'w',  # ŵ
         "\xC5\xB6"     => 'Y',  # Ŷ
         "\xC5\xB7"     => 'y',  # ŷ
         "\xC5\xB8"     => 'Y',  # Ÿ
         "\xC5\xB9"     => 'Z',  # Ź
         "\xC5\xBA"     => 'z',  # ź
         "\xC5\xBB"     => 'Z',  # Ż
         "\xC5\xBC"     => 'z',  # ż
         "\xC5\xBD"     => 'Z',  # Ž
         "\xC5\xBE"     => 'z',  # ž
         "\xC5\xBF"     => 'f',  # ſ
         "\xC6\x80"     => 'b',  # ƀ
         "\xC6\x81"     => 'B',  # Ɓ
         "\xC6\x82"     => 'B',  # Ƃ
         "\xC6\x83"     => 'b',  # ƃ
         "\xC6\x84"     => 'b',  # Ƅ
         "\xC6\x85"     => 'b',  # ƅ
         "\xC6\x86"     => 'C',  # Ɔ
         "\xC6\x87"     => 'C',  # Ƈ
         "\xC6\x88"     => 'c',  # ƈ
         "\xC6\x89"     => 'D',  # Ɖ
         "\xC6\x8A"     => 'D',  # Ɗ
         "\xC6\x8B"     => 'D',  # Ƌ
         "\xC6\x8C"     => 'd',  # ƌ
         "\xC6\x8D"     => 'g',  # ƍ
         "\xC6\x8E"     => 'E',  # Ǝ
         "\xC6\x8F"     => 'e',  # Ə
         "\xC6\x90"     => 'E',  # Ɛ
      }

      # Attribute accessor.
      attr_reader :fonts, :colours, :information, :character_set, :language,
                  :style

      # Attribute mutator.
      attr_writer :character_set, :language


      # This is a constructor for the Document class.
      #
      # ==== Parameters
      # font::       The default font to be used by the document.
      # style::      The style settings to be applied to the document. This
      #              defaults to nil.
      # character::  The character set to be applied to the document. This
      #              defaults to Document::CS_ANSI.
      # language::   The language setting to be applied to document. This
      #              defaults to Document::LC_ENGLISH_UK.
      def initialize(font, style=nil, character=CS_ANSI, language=LC_ENGLISH_UK)
         super(nil, '\rtf1')
         @fonts         = FontTable.new(font)
         @default_font  = 0
         @colours       = ColourTable.new
         @information   = Information.new
         @character_set = character
         @language      = language
         @style         = style == nil ? DocumentStyle.new : style
         @headers       = [nil, nil, nil, nil]
         @footers       = [nil, nil, nil, nil]
      end

      # Attribute accessor.
      def default_font
         @fonts[@default_font]
      end

      # This method assigns a new header to a document. A Document object can
      # have up to four header - a default header, a header for left pages, a
      # header for right pages and a header for the first page. The method
      # checks the header type and stores it appropriately.
      #
      # ==== Parameters
      # header::  A reference to the header object to be stored. Existing header
      #           objects are overwritten.
      def header=(header)
         if header.type == HeaderNode::UNIVERSAL
            @headers[0] = header
         elsif header.type == HeaderNode::LEFT_PAGE
            @headers[1] = header
         elsif header.type == HeaderNode::RIGHT_PAGE
            @headers[2] = header
         elsif header.type == HeaderNode::FIRST_PAGE
            @headers[3] = header
         end
      end

      # This method assigns a new footer to a document. A Document object can
      # have up to four footers - a default footer, a footer for left pages, a
      # footer for right pages and a footer for the first page. The method
      # checks the footer type and stores it appropriately.
      #
      # ==== Parameters
      # footer::  A reference to the footer object to be stored. Existing footer
      #           objects are overwritten.
      def footer=(footer)
         if footer.type == FooterNode::UNIVERSAL
            @footers[0] = footer
         elsif footer.type == FooterNode::LEFT_PAGE
            @footers[1] = footer
         elsif footer.type == FooterNode::RIGHT_PAGE
            @footers[2] = footer
         elsif footer.type == FooterNode::FIRST_PAGE
            @footers[3] = footer
         end
      end

      # This method fetches a header from a Document object.
      #
      # ==== Parameters
      # type::  One of the header types defined in the header class. Defaults to
      #         HeaderNode::UNIVERSAL.
      def header(type=HeaderNode::UNIVERSAL)
         index = 0
         if type == HeaderNode::LEFT_PAGE
            index = 1
         elsif type == HeaderNode::RIGHT_PAGE
            index = 2
         elsif type == HeaderNode::FIRST_PAGE
            index = 3
         end
         @headers[index]
      end

      # This method fetches a footer from a Document object.
      #
      # ==== Parameters
      # type::  One of the footer types defined in the footer class. Defaults to
      #         FooterNode::UNIVERSAL.
      def footer(type=FooterNode::UNIVERSAL)
         index = 0
         if type == FooterNode::LEFT_PAGE
            index = 1
         elsif type == FooterNode::RIGHT_PAGE
            index = 2
         elsif type == FooterNode::FIRST_PAGE
            index = 3
         end
         @footers[index]
      end

      # Attribute mutator.
      #
      # ==== Parameters
      # font::  The new default font for the Document object.
      def default_font=(font)
         @fonts << font
         @default_font = @fonts.index(font)
      end

      # This method provides a short cut for obtaining the Paper object
      # associated with a Document object.
      def paper
         @style.paper
      end

      # This method overrides the parent=() method inherited from the
      # CommandNode class to disallow setting a parent on a Document object.
      #
      # ==== Parameters
      # parent::  A reference to the new parent node for the Document object.
      #
      # ==== Exceptions
      # RTFError::  Generated whenever this method is called.
      def parent=(parent)
         RTFError.fire("Document objects may not have a parent.")
      end

      # This method inserts a page break into a document.
      def page_break
         self.store(CommandNode.new(self, '\page', nil, false))
         nil
      end

      # This method fetches the width of the available work area space for a
      # typical Document object page.
      def body_width
         @style.body_width
      end

      # This method fetches the height of the available work area space for a
      # a typical Document object page.
      def body_height
         @style.body_height
      end

      # This method generates the RTF text for a Document object.
      def to_rtf
         text = StringIO.new

         text << "{#{prefix}\\#{@character_set.id2name}"
         text << "\\deff#{@default_font}"
         text << "\\deflang#{@language}" if @language != nil
         text << "\\plain\\fs24\\fet1"
         text << "\n#{@fonts.to_rtf}"
         text << "\n#{@colours.to_rtf}" if @colours.size > 0
         text << "\n#{@information.to_rtf}"
         if @headers.compact != []
            text << "\n#{@headers[3].to_rtf}" if @headers[3] != nil
            text << "\n#{@headers[2].to_rtf}" if @headers[2] != nil
            text << "\n#{@headers[1].to_rtf}" if @headers[1] != nil
            if @headers[1] == nil or @headers[2] == nil
               text << "\n#{@headers[0].to_rtf}"
            end
         end
         if @footers.compact != []
            text << "\n#{@footers[3].to_rtf}" if @footers[3] != nil
            text << "\n#{@footers[2].to_rtf}" if @footers[2] != nil
            text << "\n#{@footers[1].to_rtf}" if @footers[1] != nil
            if @footers[1] == nil or @footers[2] == nil
               text << "\n#{@footers[0].to_rtf}"
            end
         end
         text << "\n#{@style.prefix(self)}" if @style != nil
         self.each {|entry| text << "\n#{entry.to_rtf}"}
         text << "\n}"

         # Protect non-ASCII characters using "\uNNNx" notation.
         text.string.gsub(/[^ -~\t\r\n]/) do |char|
            safe = ASCII_EQUIVALENTS[char] || '?'
            begin
               uni = *char.unpack('U')
               uni -= 65536 if uni >= 32768
               '\\u' + uni.to_s + safe
            rescue
               safe
            end
         end
      end
   end # End of the Document class.
end # End of the RTF module.
