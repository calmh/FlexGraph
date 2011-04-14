# Add data to the PlotLine by shifting it in. It should be a two-column array,
# where the first column is time and the second is value.
# Times should be in the form of UNIX epoch seconds.
#  line = PlotLine.new
#  line << [ 1234567890, 1e6 ]
#  line << [ 1234568390, 1.5e6 ]
class PlotLine
  # An RGB color on the form '#aabbcc'.
  # Leave this at nil (default) to use theme colors when plotting.
  attr_accessor :color
  # Line width in pixels.
  # Leave this at nil (default) to use theme width when plotting.
  attr_accessor :width
  # Plot style.
  # Leave this at nil (default) to use theme style when plotting.
  attr_accessor :style
  # String signifying the unit of the data, i.e. 'bps'.
  attr_accessor :unit
  # Multiplier to apply just before plotting.
  attr_accessor :multiplier
  # Title to give this line
  attr_accessor :title
  # Start end end time values of the dataset
  attr_reader :start_time, :end_time
  # Which axes to plot this line on. Nil defaults to x1y1.
  attr_accessor :axes
  # Whether to use long title (with max/min etc) or not. Defaults to not.
  attr_accessor :use_long_title

  def initialize
    @multiplier = 1
    @data = []
  end

  def <<(value)
    @data << value
    @max = [ @max, value[1..-1] ].flatten.compact.max
    @min = [ @min, value[1..-1] ].flatten.compact.min
    @start_time = [ @start_time, value[0] ].compact.min
    @end_time = [ @end_time, value[0] ].compact.max
  end

  def min
    (@min || 0) * multiplier
  end

  def max
    (@max || 0) * multiplier
  end

  def avg
    return 0 if @data.length == 0
    @data.inject(0) { |n, m| n += m[1] } / @data.length  * multiplier
  end

  def pct(p)
    return 0 if @data.length == 0
    l = @data.sort { |a, b| a[1] <=> b[1] }
    return l[l.length * p / 100][1] * multiplier
  end

  def long_title
    title + " (Max: #{format_number(max)}, Avg: #{format_number(avg)}, 95%: #{format_number(pct(95))}, Min: #{format_number(min)} #{unit})"
  end

  def column_expression
    return "1:2" if @data.length == 0
    (1..@data[0].length).to_a.join ":"
  end

  def plot_command
    cmd = "\"-\" using " + column_expression
    cmd += " axes #{axes}" if !axes.nil?
    cmd += " with #{style}" if !style.nil?
    if use_long_title
      cmd += " title \"#{long_title}\"" if !title.nil?
    else
      cmd += " title \"#{title}\"" if !title.nil?
    end
    cmd += " lw #{width}" if !width.nil?
    cmd += " lt rgb \"#{color}\"" if !color.nil?
    return cmd
  end

  def plot_data
    if @data.empty?
      return "0 0\ne\n"
    else
    @data.map{ |d| d[0].to_s + " " + (d[1..-1].map{ |x| multiplier * x }.join " ") + "\n" }.join + "e\n"
    end
  end

  private
  def format_number(num)
    return "%6.02fG"%(num / 1e9) if num.abs > 1e9
    return "%6.01fM"%(num / 1e6) if num.abs > 1e6
    return "%6.01fK"%(num / 1e3) if num.abs > 1e5
    return "%7.0f"%num
  end
end

class PlotTheme
  attr_accessor :line_colors
  attr_accessor :line_width
  attr_accessor :line_style
  attr_accessor :background_color
  attr_accessor :plot_background_color
  attr_accessor :primary_grid_color
  attr_accessor :secondary_grid_color
  # Font face name. The font file needs to reside in GDFONTPATH for this to work.
  #  font_face = "LiberationSans-Regular"
  attr_accessor :font_face
  # Font size (points)
  attr_accessor :font_size
  # Font face name. The font file needs to reside in GDFONTPATH for this to work.
  #  font_face = "LiberationSans-Regular"
  attr_accessor :title_font_face
  # Font size (points)
  attr_accessor :title_font_size

  def initialize
    @line_colors = []
    @background_color = "#ffffff"
    @primary_grid_color = "#808080"
    @secondary_grid_color = @primary_grid_color
  end

  def line_color(i)
    return nil if @line_colors.length == 0
    @line_colors[i % @line_colors.length]
  end
end

class Plot
  # The PlotTheme to apply
  attr_accessor :theme
  # The title of the graph
  attr_accessor :title
  # Width of graph, in pixels
  attr_accessor :width
  # Height of graph, in pixels
  attr_accessor :height
  # Units for the two axes
  attr_reader :y1unit, :y2unit
  attr_reader :y1max, :y1min
  attr_reader :y2max, :y2min

  def initialize
    @lines = []
    @width = 500
    @height = 200
    @y1min = @y1max = @y2min = @y2max = 0
  end

  def <<(line)
    @lines << line

    @y1unit ||= line.unit
    if line.unit != @y1unit && @y2unit.nil?
      @y2unit = line.unit
    end

    if line.unit == @y1unit
      line.axes = 'x1y1'
      @y1min = [ 0, @y1min, line.min ].min
      @y1max = [ @y1max, line.max ].max
    else
      line.axes = 'x1y2'
      @y2min = [ 0, @y2min, line.min ].min
      @y2max = [ @y2max, line.max ].max
    end
  end

  def setup_command
    cmds = []
    if @theme.nil? || @theme.font_face.nil?
      cmds << "set terminal png small size #{width}, #{height} \\"
    else
      cmds << "set terminal png font \"#{@theme.font_face}\" #{@theme.font_size} size #{width}, #{height} \\"
    end
    if @theme.nil?
      cmds << "xffffff x808080 x808080"
    else
      cmds << [ @theme.background_color, @theme.primary_grid_color, @theme.secondary_grid_color ].join(' ').gsub('#', 'x')
    end
    height = 0.46 + 0.03 * @lines.length
    cmds << "set xdata time"
    cmds << "set timefmt \"%s\""
    cmds << "set xrange [#{start_time - 946684800}:#{end_time - 946684800 + 1}]"
    ten_pct = (y1max - y1min) * 0.1
    cmds << "set yrange [#{y1min - ten_pct}:#{y1max + ten_pct + 1}]"
    ten_pct = (y2max - y2min) * 0.1
    cmds << "set y2range [#{y2min - ten_pct}:#{y2max + ten_pct + 1}]"
    cmds << "set lmargin 10"
    if @y2unit.nil?
      cmds << "set rmargin 2"
    else
      cmds << "set rmargin 10"
    end
    cmds << "set format x \"%d/%m\\n%H:%M\""
    cmds << "set format y \"%.1s%c\""
    cmds << "set format y2 \"%.1s%c\""
    cmds << "set grid"
    cmds << "set style fill solid 0.25 border"
    cmds << "set key below Right samplen 2 left reverse"
    if @theme.nil? || @theme.title_font_face.nil?
      cmds << "set title \"#{title}\""
    else
      cmds << "set title \"#{title}\" font \"#{@theme.title_font_face}, #{@theme.title_font_size}\""
    end
    cmds << "set ylabel \"#{@y1unit}\""
    cmds << "set y2label \"#{@y2unit}\""
    cmds << "set ytics nomirror"
    cmds << "set y2tics"
    if !@theme.nil? && !@theme.plot_background_color.nil?
      cmds << "set obj 20 rect from graph 0, graph 0 to graph 1, graph 1 fs solid fc rgb \"#{@theme.plot_background_color}\" behind"
    end
    cmds.join("\n") + "\n"
  end

  def end_time
    begin
    @lines.map{ |l| l.end_time }.sort.reverse[0]
    rescue
      return 0
    end
  end

  def start_time
    begin
    @lines.map{ |l| l.start_time }.sort[0]
    rescue
      return 0
    end
  end

  # Sets the first unit found on x1y1, all others on x1y2
  def set_axes
    unit = nil
    @lines.each do |line|
      unit = line.unit if unit.nil?
      if unit == line.unit
        line.axes = 'x1y1'
      else
        line.axes = 'x1y2'
      end
    end
  end

  def plot_command
    set_axes
    i = -1
    parts = @lines.map { |l| themed(l, i+=1).plot_command }
    "plot \\\n" + parts.join(", \\\n") + "\n"
  end

  def plot_data
    @lines.map{ |l| l.plot_data }.join("\n") + "\n"
  end

  def png
    io = IO.popen "gnuplot", "r+"
    io.puts setup_command
    io.puts plot_command
    io.puts plot_data
    io.close_write
    return io.read
  end

  private
  def themed(line, i)
    return line if @theme.nil?
    line = line.dup
    line.color = @theme.line_color(i) if line.color.nil?
    line.width = @theme.line_width if line.width.nil?
    line.style = @theme.line_style if line.style.nil?
    return line
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'test/unit'
  class TestAggregator < Test::Unit::TestCase
    def test_plotline_should_generate_default_style
      l = PlotLine.new
      l << [ 0, 0 ]
      cmd = l.plot_command
      assert_equal '"-" using 1:2', cmd
    end

    def test_plotline_should_have_style
      l = PlotLine.new
      l << [ 0, 0 ]
      l.style = "steps"
      cmd = l.plot_command
      assert_equal '"-" using 1:2 with steps', cmd
    end

    def test_plotline_should_have_title
      l = PlotLine.new
      l << [ 0, 0 ]
      l.title = "Plot one"
      cmd = l.plot_command
      assert_equal '"-" using 1:2 title "Plot one"', cmd
    end

    def test_plotline_should_have_width
      l = PlotLine.new
      l << [ 0, 0 ]
      l.width = 2
      cmd = l.plot_command
      assert_equal '"-" using 1:2 lw 2', cmd
    end

    def test_plotline_should_have_color
      l = PlotLine.new
      l << [ 0, 0 ]
      l.color = "#123456"
      cmd = l.plot_command
      assert_equal '"-" using 1:2 lt rgb "#123456"', cmd
    end

    def test_plotline_should_have_style_title_width_and_color
      l = PlotLine.new
      l << [ 0, 0 ]
      l.style = "steps"
      l.title = "Plot one"
      l.color = "#123456"
      l.width = 2
      cmd = l.plot_command
      assert_equal('"-" using 1:2 with steps title "Plot one" lw 2 lt rgb "#123456"', cmd)
    end

    def test_plotline_should_return_data
      l = PlotLine.new
      l << [ 1000, 10 ]
      l << [ 1300, 20 ]
      l << [ 1600, 30 ]
      assert_equal "1000 10\n1300 20\n1600 30\ne\n", l.plot_data
    end

    def test_plotline_should_premultiply_data
      l = PlotLine.new
      l.multiplier = 8
      l << [ 1000, 10 ]
      l << [ 1300, 20 ]
      l << [ 1600, 30 ]
      assert_equal "1000 80\n1300 160\n1600 240\ne\n", l.plot_data
    end

    def test_plotline_should_keep_track_of_endpoints
      l = PlotLine.new
      l << [ 1000, 10 ]
      l << [ 1300, 30 ]
      l << [ 1600, 20 ]
      assert_equal 1000, l.start_time
      assert_equal 1600, l.end_time
      assert_equal 10, l.min
      assert_equal 30, l.max
      assert_equal 20, l.avg
      l.multiplier = 8
      assert_equal 80, l.min
      assert_equal 240, l.max
      assert_equal 160, l.avg
    end

    def test_plot_should_keep_track_of_endpoints
      l1 = PlotLine.new
      l1 << [ 1000, 10 ]
      l1 << [ 1300, 30 ]
      l2 = PlotLine.new
      l2 << [ 1100, 15 ]
      l2 << [ 1400, 35 ]
      l2 << [ 1700, 25 ]
      p = Plot.new
      p << l1
      p << l2
      assert_equal 1000, p.start_time
      assert_equal 1700, p.end_time
    end

    def test_plot_should_return_two_plot_commands
      l1 = PlotLine.new
      l1 << [ 1, 1 ]
      l2 = PlotLine.new
      l2 << [ 1, 1 ]
      p = Plot.new
      p << l1
      p << l2
      assert_equal "plot \\\n\"-\" using 1:2 axes x1y1, \\\n\"-\" using 1:2 axes x1y1\n", p.plot_command
    end

    def test_plot_should_set_different_axes_labels
      l1 = PlotLine.new
      l1 << [ 1, 1 ]
      l1.unit = 'u1'
      l2 = PlotLine.new
      l2 << [ 1, 1 ]
      l2.unit = 'u2'
      p = Plot.new
      p << l1
      p << l2
      assert_equal 'u1', p.y1unit
      assert_equal 'u2', p.y2unit
    end

    def test_plot_should_return_two_plot_commands_with_different_axes
      l1 = PlotLine.new
      l1 << [ 1, 1 ]
      l1.unit = 'u1'
      l2 = PlotLine.new
      l2 << [ 1, 1 ]
      l2.unit = 'u2'
      p = Plot.new
      p << l1
      p << l2
      assert_equal "plot \\\n\"-\" using 1:2 axes x1y1, \\\n\"-\" using 1:2 axes x1y2\n", p.plot_command
    end

    def test_theme_shold_return_nil_color_if_there_are_none
      t = PlotTheme.new
      assert_nil t.line_color(42)
    end

    def test_theme_should_iterate_over_colors
      t = PlotTheme.new
      t.line_colors << "#000000"
      t.line_colors << "#111111"
      t.line_colors << "#222222"
      assert_equal "#111111", t.line_color(1)
      assert_equal "#222222", t.line_color(5)
      assert_equal "#000000", t.line_color(9)
    end

    def test_plot_should_return_two_themed_plot_commands
      l1 = PlotLine.new
      l1 << [ 1, 1 ]
      l2 = PlotLine.new
      l2 << [ 1, 1 ]
      t = PlotTheme.new
      t.line_colors << "#000000"
      t.line_colors << "#111111"
      p = Plot.new
      p << l1
      p << l2
      p.theme = t
      assert_equal "plot \\\n\"-\" using 1:2 axes x1y1 lt rgb \"#000000\", \\\n\"-\" using 1:2 axes x1y1 lt rgb \"#111111\"\n", p.plot_command
    end
  end
end

