#!/usr/bin/env ruby

require 'gnuplotter'
require 'extractor/rtg'
require 'cgi'

cgi = CGI.new

ids = cgi.params['id'][0].split(/p|\s+/).map { |e| e.split(':').map(&:to_i) }

title = cgi.params['title'][0] || 'Untitled traffic graph'

if cgi.params.include? 'secs'
  secs = cgi.params['secs'][0].to_i
else
  secs = 86400
end

t = PlotTheme.new
t.line_width = 1
t.line_colors << "#eb690b"
t.line_colors << "#00a0e1"
t.line_colors << "#97bf0d"
t.line_colors << "#b5007c"
t.line_style = "fsteps"
t.background_color = "#ffffff"
t.plot_background_color = "#202020"
t.primary_grid_color = "#000000"
t.secondary_grid_color = "#505050"
t.font_face = "ttf-liberation/LiberationMono-Regular"
t.font_size = 8
t.title_font_face = "ttf-liberation/LiberationSans-Bold"
t.title_font_size = 11

p = Plot.new
p.theme = t
p.title = title
p.width = 640
p.height = 250

l1 = PlotLine.new
l1.title = "In traffic"
l1.unit = "bps"
l1.multiplier = 8 # RTG returns bytes/s
l1.use_long_title = true

l2 = PlotLine.new
l2.title = "Out traffic"
l2.unit = "bps"
l2.multiplier = 8
l2.use_long_title = true

ex = RTGExtractor.new
rows = ex.traffic_data_added ids, secs
rows.each do |time, in_o, out_o|
  l1 << [ time, in_o ]
  l2 << [ time, out_o ]
end
p << l1
p << l2

puts "Content-type: image/png\n\n"
puts p.png

