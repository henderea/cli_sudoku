require 'json'

# Array.fill2d
class Array
  def self.fill2d(rows, cols, value)
    arr = Array.new(rows)
    0.upto(rows - 1) { |i|
      arr[i] = Array.new(cols, value)
    }
    arr
  end

  def join_in_groups(item_join_str, group_join_str, group_size)
    each_slice(group_size).map { |v| v.join(item_join_str) }.join(group_join_str)
  end

  def not_empty?
    !empty?
  end
end

# Random.rand modification
class Random
  alias old_rand rand

  def rand(a = nil, b = nil)
    if a.nil?
      old_rand
    elsif b.nil? && a.respond_to?(:to_a)
      arr = a.to_a
      arr[old_rand(arr.count)]
    elsif b.nil?
      old_rand(a)
    else
      old_rand(b - a) + a
    end
  end

  def original_rand(max, tried_vals)
    loop do
      i = rand(max)
      return i unless tried_vals.include?(i) || yield(i)
    end
    nil
  end
end

Square = Struct.new(:across, :down, :region, :value, :index)

# Helpers for the sudoku board
module SudokuBoardHelpers
  def across_from_number(n)
    k = n % 9
    k.zero? ? 9 : k
  end

  def down_from_number(n)
    across_from_number(n) == 9 ? (n / 9).floor : (n / 9).floor + 1
  end

  def sub_index_from_number(n)
    a = across_from_number n
    d = down_from_number n
    (((d - 1) % 3) * 3) + ((a - 1) % 3) + 1
  end

  def row_col_from_sub_index(s)
    [((s - 1) / 3).floor + 1, ((s - 1) % 3) + 1]
  end

  def region_from_number(n)
    a = across_from_number n
    d = down_from_number n
    (((d - 1) / 3).floor * 3) + ((a - 1) / 3).floor + 1
  end

  def row_col_from_region_sub_index(r, s)
    row1, col1 = row_col_from_sub_index r
    row2, col2 = row_col_from_sub_index s
    [((row1 - 1) * 3) + row2, ((col1 - 1) * 3) + col2]
  end

  def copy_data(data)
    data.map { |s| item(s.index, s.value) }
  end

  def item(n, v)
    n += 1
    Square.new(across_from_number(n), down_from_number(n), region_from_number(n), v, n - 1)
  end
end

# noinspection RubyResolve
# Helpers for the sudoku generation
module SudokuHelpers
  include SudokuBoardHelpers

  DIFFICULTY_SPACES = {
    easy:   (35...45),
    medium: (30...35),
    hard:   (25...30)
  }.freeze

  def nonzero_and_equal(s, test, method)
    sv = s[method.to_sym]
    tv = test[method.to_sym]
    sv != 0 && sv == tv
  end

  def clear_rc(m)
    0.upto(8) { |a| m[yield(a).value] = 0 }
  end

  def conflicts?(current_values, test)
    current_values.any? { |s|
      s && (nonzero_and_equal(s, test, :across) ||
        nonzero_and_equal(s, test, :down) ||
        nonzero_and_equal(s, test, :region)) && s.value == test.value
    }
  end

  def generate_to_s(sudoku)
    border  = Array.new(9, '---').join_in_groups '+', '++', 3
    border  = "++#{border}++"
    border2 = border.tr '-', '='
    str     = (0...9).map { |i|
      v = (0...9).map { |j|
        cell_to_s(i, j, sudoku)
      }.join_in_groups ' | ', ' || ', 3
      "|| #{v} ||"
    }.join_in_groups "\n#{border}\n", "\n#{border2}\n", 3
    "#{border}\n#{str}\n#{border}"
  end

  def cell_to_s(i, j, sudoku)
    cell = sudoku.cell_rc(i, j)
    val  = cell.nil? ? 0 : cell.value
    (val.zero? ? '•' : val.to_s)
  end

  def to_m(arr)
    matrix = Array.fill2d(9, 9, 0)
    arr.each { |square| matrix[square.down - 1][square.across - 1] = square.value }
    matrix
  end
end

# Data storage and access for the board
class SudokuBoard
  include SudokuBoardHelpers

  def initialize
    @board = []
  end

  def [](i)
    @board[i]
  end

  def []=(i, v)
    @board[i] = v
  end

  def clear
    @board = []
  end

  def cell_rc(row, col)
    @board[row * 9 + col]
  end

  def cell_rs(region, sub_index)
    row, col = row_col_from_region_sub_index region, sub_index
    cell_rc row - 1, col - 1
  end

  def data
    copy_data @board
  end

  def data=(data)
    @board = copy_data data
  end

  def number_spots
    @board.map { |square| square.nil? || square.value.zero? ? 0 : 1 }.reduce(&:+)
  end

  def <<(v)
    @board << v
  end

  def each(&block)
    @board.each(&block)
  end
end

# noinspection RubyResolve
# Helpers for generating the sudoku
module SudokuGeneratorHelpers
  include SudokuHelpers

  def generate_grid(sudoku, rand)
    squares   = Array.new(81, nil)
    available = Array.new(81) { |_| (1..9).to_a }
    c         = 0
    until c == 81
      c = available[c].not_empty? ? update_available(available, c, rand, squares) : reset_available(available, c, squares)
    end
    sudoku.data = squares
    sudoku.data
  end

  def update_available(available, c, rand, squares)
    i = rand.rand(available[c].count)
    z = available[c][i]
    if conflicts?(squares, item(c, z))
      available[c].delete_at(i)
    else
      squares[c] = item(c, z)
      available[c].delete_at(i)
      c += 1
    end
    c
  end

  def reset_available(available, c, squares)
    available[c]   = (1..9).to_a
    squares[c - 1] = nil
    c - 1
  end

  def try_value(i, sudoku)
    old_value       = sudoku[i].value
    sudoku[i].value = 0
    sudoku[i].value = old_value unless sudoku_unique?(sudoku)
  end

  def sudoku_unique?(sudoku)
    m           = sudoku.data
    b           = test_uniqueness(sudoku) == :unique
    sudoku.data = m
    b
  end

  def test_uniqueness(sudoku)
    # Find untouched location with most information
    cmp, colp, mp, rowp = uniqueness_cmp(sudoku)

    # Finished?
    return :unique if cmp == 10

    # Couldn't find a solution?
    return :no_solution if cmp.zero?

    # Try elements
    success = try_elements(colp, mp, rowp, sudoku)

    # More than one solution found?
    return :not_unique if success > 1

    # Restore to original state.
    sudoku.cell_rc(rowp, colp).value = 0

    if success.zero?
      :no_solution
    elsif success == 1
      :unique
    else
      :not_unique
    end
  end

  def try_elements(colp, mp, rowp, sudoku)
    success = 0
    1.upto(9) { |i|
      next if mp[i].zero?
      sudoku.cell_rc(rowp, colp).value = mp[i]

      test_result = test_uniqueness(sudoku)
      if test_result == :unique
        success += 1
      elsif test_result == :not_unique
        success = 100
        break
      end
    }
    success
  end

  def uniqueness_cmp(sudoku)
    rowp = 0
    colp = 0
    mp   = nil
    cmp  = 10

    0.upto(8) { |row|
      0.upto(8) { |col|
        # Is this spot unused?
        next unless sudoku.cell_rc(row, col).value.zero?
        # Set M of possible solutions
        cm, m = check_solutions(col, row, sudoku)

        # Is there more information in this spot than in the best yet?
        next unless cm < cmp
        cmp  = cm
        mp   = m
        colp = col
        rowp = row
      }
    }
    [cmp, colp, mp, rowp]
  end

  def check_solutions(col, row, sudoku)
    m = (0..9).to_a

    # Remove used numbers in the vertical direction
    clear_rc(m) { |a| sudoku.cell_rc(a, col) }

    # Remove used numbers in the horizontal direction
    clear_rc(m) { |b| sudoku.cell_rc(row, b) }

    # Remove used numbers in the sub square.
    square_index = sudoku.cell_rc(row, col).region
    clear_rc(m) { |c| sudoku.cell_rs(square_index, c + 1) }

    # Calculate cardinality of M
    cm = (1..9).map { |d| m[d].zero? ? 0 : 1 }.sum
    [cm, m]
  end
end

# noinspection RubyResolve
# The main sudoku generator
class Sudoku
  include SudokuHelpers
  include SudokuGeneratorHelpers

  def initialize
    @rand        = Random.new
    @sudoku      = SudokuBoard.new
    @full_sudoku = SudokuBoard.new
  end

  def generate_difficulty(difficulty)
    generate(@rand.rand(DIFFICULTY_SPACES[difficulty]))
  end

  def generate(spaces = 81, max_tries = 100_000)
    @sudoku.clear
    @full_sudoku.clear
    @full_sudoku.data = generate_grid(@sudoku, @rand)
    time1, tries      = create_game_from_full_board(max_tries, spaces)
    if @sudoku.number_spots == spaces
      [tries, true, (Time.now - time1)]
    else
      @sudoku.data = @full_sudoku.data
      [tries, false, Time.now - time1]
    end
  end

  def create_game_from_full_board(max_tries, spaces)
    tries = 0
    time1 = Time.now
    max_tries.times {
      tried_inds = []
      tries      += 1
      while @sudoku.number_spots > spaces && tried_inds.count < 81
        i = try_helper(tried_inds)
        tried_inds << i
        try_value i, @sudoku
      end
      break if @sudoku.number_spots == spaces
    }
    [time1, tries]
  end

  def try_helper(tried_inds)
    @rand.original_rand(81, tried_inds) { |v| @sudoku[v].value.zero? }
  end

  def clear
    @sudoku.clear
    @full_sudoku.clear
  end

  def data
    @sudoku.data
  end

  def data=(data)
    @sudoku.data = data
  end

  def to_s
    generate_to_s(@sudoku)
  end

  # noinspection RubyStringKeysInHashInspection
  def to_json
    matrix1 = to_m @sudoku
    matrix2 = to_m @full_sudoku
    { game: matrix1, full: matrix2.inspect }.to_json
  end
end