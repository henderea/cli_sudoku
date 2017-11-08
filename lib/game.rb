# noinspection RubyResolve

# Represents the current location on the board
class Location
  attr_reader :max, :sub

  class << self
    def create_axis_accessor(name, axis, field)
      define_method(name.to_sym) { instance_variable_get("@#{field}".to_sym)[axis] }
      define_method("#{name}=".to_sym) { |val| instance_variable_get("@#{field}".to_sym)[axis] = val }
    end

    def create_move_method(*types)
      types.each { |type| define_method(type.to_sym) { move(type.to_sym) } }
    end
  end

  create_axis_accessor :x, 0, :pos
  create_axis_accessor :y, 1, :pos
  create_axis_accessor :mode_x, 0, :mode
  create_axis_accessor :mode_y, 1, :mode

  create_move_method :up, :down, :left, :right

  def initialize(x = 0, y = 0, max = 9, sub = 3, mode_x = :wrap_same, mode_y = :wrap_same)
    @pos  = [x, y]
    @max  = max
    @sub  = sub
    @mode = [mode_x, mode_y]
  end

  def move(dir)
    case dir
      when :up
        move2(-1, 1)
      when :down
        move2(1, 1)
      when :left
        move2(-1, 0)
      when :right
        move2(1, 0)
      else
        raise "Not a valid direction: #{dir}"
    end
  end

  def move2(cnt, axis, itr = false)
    unless cnt.zero?
      mode = @mode[axis]
      case mode
        when :wrap_same
          move_sub(cnt, 0, axis, @max, itr)
        when :wrap_same_sub
          move_sub(cnt, 0, axis, @sub, itr)
        when :wrap_next
          move_sub(cnt, cnt, axis, @max, itr)
        when :wrap_next_sub
          move_sub(cnt, cnt, axis, @sub, itr)
        else
          raise "Not a valid mode for axis #{%w[x y][axis]}: #{mode}"
      end
    end
    [x, y]
  end

  def move_sub(cnt, cnt2, axis, max, itr)
    pos        = @pos[axis]
    sub        = (pos / max).floor
    sub_pos    = pos % max
    sub_pos    += cnt
    sub_pos2   = sub_pos % max
    @pos[axis] = sub_pos2 + (sub * max)
    move2(cnt2, 1 - axis, true) if sub_pos2 != sub_pos && !itr
  end

  def inspect
    "pos: (#{x}, #{y}); mode: (#{mode_x}, #{mode_y}); max: #{max}; sub: #{sub}"
  end

  def abs_pos
    (y * max) + x
  end

  private :move2, :move_sub
end

# Represents a space on the board
class Space
  attr_accessor :value

  def initialize
    @value = 0
    @notes = Array.new(9, false)
  end
end

# The game instance
class Game
  def initialize
    @loc     = Location.new(0, 0)
    @sub_loc = Location.new(0, 0)
    @spaces  = Array.new(9 * 9) { Space.new }
  end
end
