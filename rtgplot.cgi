#!/usr/bin/env ruby

require 'lib/gnuplotter'
require 'extractor/rtg'
require 'cgi'

def secs_to_human(secs)
  parts = []
  if secs > 86400
    parts << "%d d"%[secs / 86400]
    secs %= 86400
  end
  if secs > 3600
    parts << "%d h"%[secs / 3600]
    secs %= 3600
  end
  if secs > 60
    parts << "%d m"%[secs / 60]
    secs %= 60
  end
  return parts.join ", "
end

cgi = CGI.new

ids = cgi.params['id'][0].split(/p|\s+/).map { |e| e.split(':').map(&:to_i) }
width = (cgi.params['w'][0] || 640).to_i
height = (cgi.params['h'][0] || 250).to_i
debug = cgi.params['debug'][0].to_i
old = cgi.params['old'][0].to_i

if cgi.params.include? 'secs'
  secs = cgi.params['secs'][0].to_i
else
  secs = 86400
end

title = (cgi.params['title'][0] || 'Untitled traffic graph') + " (" + secs_to_human(secs) + ")"

t = PlotTheme.new
t.line_width = 1
t.line_colors << "#eb690b"
t.line_colors << "#00a0e1"
t.line_colors << "#97bf0d"
t.line_colors << "#b5007c"
if old == 1
  t.line_style = "fsteps"
else
  t.line_style = "filledcurve y1=0"
end
t.background_color = "#ffffff"
t.plot_background_color = "#f0f0f0"
t.primary_grid_color = "#606060"
t.secondary_grid_color = "#d0d0d0"
t.font_face = "ttf-liberation/LiberationMono-Regular"
t.title_font_face = "ttf-liberation/LiberationSans-Bold"

if width >= 500
  t.font_size = 8
  t.title_font_size = 10
  long_title = true
else
  t.font_size = 7
  t.title_font_size = 9
  long_title = false
end

p = Plot.new
p.theme = t
p.title = title
p.width = width
p.height = height

fake_steps = (old == 0)
l1 = PlotLine.new
l1.title = "In traffic"
l1.unit = "bps"
l1.multiplier = 8 # RTG returns bytes/s
l1.use_long_title = long_title
l1.fake_steps = fake_steps

l2 = PlotLine.new
l2.title = "Out traffic"
l2.unit = "bps"
l2.multiplier = 8
l2.use_long_title = long_title
l2.fake_steps = fake_steps

ex = RTGExtractor.new
rows = ex.traffic_data_added ids, secs
rows.each do |time, in_o, out_o|
  l1 << [ time, in_o ]
  if old == 1
    l2 << [ time, out_o ]
  else
    l2 << [ time, -out_o ]
  end
end
p << l1
p << l2

if debug == 1
  puts "Content-type: text/plain\n\n"
  puts p.setup_command
  puts p.plot_command
  puts p.plot_data
else
  puts "Content-type: image/png\n\n"
  puts p.png
end

