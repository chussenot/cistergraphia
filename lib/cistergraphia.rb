# Cistergraphia Core Module
# ========================
#
# Purpose:
# - Core encryption logic for the Cistercian number system
# - SVG symbol generation and layout calculations
#
# Design Decisions:
# - Module-based design for encapsulation
# - Fixed symbol dimensions for consistent layout
# - Randomized number splitting for added complexity
# - Snail pattern layout for aesthetic presentation
# - Evil symbol injection for perfect square grid
#
# Constraints:
# - Limited to ASCII characters defined in TABLET
# - Symbol dimensions are fixed (100x100)
# - Numbers must be converted to specific line patterns
# - Grid must be a perfect square

# Move the core functionality into a module
module Cistergraphia
  # Constants for layout and symbol dimensions
  SPACE = 20
  PADDING = 50  # Add padding around the content
  SYMBOL_WIDTH = 100  # Width of each symbol
  SYMBOL_HEIGHT = 100  # Height of each symbol

  # Mapping of characters to numerical values
  TABLET = {
    a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9, j: 10,
    k: 11, l: 12, m: 13, n: 14, o: 15, p: 16, q: 18, r: 19, s: 100,
    t: 200, u: 300, v: 400, w: 500, x: 600, y: 700, z: 800, " ": 900
  }.freeze

  module_function

  # Converts a message into a sequence of numbers using the TABLET mapping
  def cister(message)
    message.downcase
           .gsub(/\W/, ' ')  # Replace non-word characters with space
           .squeeze(' ')     # Remove consecutive spaces
           .strip            # Remove leading and trailing spaces
           .chars            # Convert string to array of characters
           .map { |c| TABLET[c.to_sym] * 10 }  # Map each character to its value and multiply by 10
           .flat_map { |n| [n - rand(n), rand(n)].shuffle }  # Split each number into two random parts
  end

  # Breaks a number into its individual digits, each multiplied by its place value
  def digits(num)
    num.to_s.chars.reverse.map.with_index { |c, i| c.to_i * (10**i) }.reverse
  end

  # Arranges an array in a snail pattern (spiral order)
  def snail(array)
    return [] if array.empty?
    array.shift + snail(array.transpose.reverse)
  end

  # Randomly inserts a pair of 'evil' symbols into the array
  def inject_evil_symbols(array)
    array.insert(rand(0..array.length), [rand(9999), 9999]).flatten!
  end

  # Checks if a number is a perfect square
  def perfect_square?(x)
    Math.sqrt(x) % 1 == 0
  end

  # Calculates the dimensions needed to display the sequence in a grid
  def calculate_dimensions(sequence)
    cols = Math.sqrt(sequence.size).to_i  # Calculate number of columns
    rows = (sequence.size.to_f / cols).ceil  # Calculate number of rows
    
    # Calculate total width and height including padding
    width = (SYMBOL_WIDTH + SPACE) * cols + PADDING * 2
    height = (SYMBOL_HEIGHT + SPACE) * rows + PADDING * 2
    
    [width, height, cols, rows]
  end

  # Draws a symbol at a specific position in the document
  def symbol(doc, ds, index, y = 0)
    # Calculate x position with padding
    x = PADDING + (SYMBOL_WIDTH + SPACE) * index
    # Draw the main vertical line of the symbol
    doc.line(
      x1: 50 + x,
      y1: 0 + y,
      x2: 50 + x,
      y2: SYMBOL_HEIGHT + y,
      style: 'stroke:black; stroke-width:2;'
    )
    # Draw additional lines based on the digits
    ds.each { |num| draw_line(doc, num, x, y) }
  end

  # Draws lines for a given number based on predefined mappings
  def draw_line(doc, num, x, y)
    # Define line mappings for different numbers
    line_mappings = {
      [1, 5, 7, 9] => [50, 0, 100, 0],
      [2, 8, 9] => [50, 50, 100, 50],
      [3] => [50, 0, 100, 50],
      [4] => [50, 50, 100, 0],
      [6, 7, 8, 9] => [100, 0, 100, 50],
      [10, 50, 70, 90] => [50, 0, 0, 0],
      [20, 80, 90] => [50, 50, 0, 50],
      [30] => [50, 0, 0, 50],
      [40, 50] => [50, 50, 0, 0],
      [60, 70, 80, 90] => [0, 50, 0, 0],
      [100, 500, 700, 900] => [50, 100, 100, 100],
      [200, 800, 900] => [50, 50, 100, 50],
      [300] => [50, 100, 100, 50],
      [400, 500] => [50, 50, 100, 100],
      [600, 700, 800, 900] => [100, 50, 100, 100],
      [1000, 5000, 7000, 9000] => [50, 100, 0, 100],
      [2000, 8000, 9000] => [50, 50, 0, 50],
      [3000] => [50, 100, 0, 50],
      [4000, 5000] => [50, 50, 0, 100],
      [6000, 7000, 8000, 9000] => [0, 50, 0, 100]
    }

    # Draw the line corresponding to the number
    line_mappings.each do |keys, coords|
      if keys.include?(num)
        doc.line(
          x1: coords[0] + x,
          y1: coords[1] + y,
          x2: coords[2] + x,
          y2: coords[3] + y,
          style: 'stroke:black; stroke-width:2;'
        )
        break
      end
    end
  end
end 