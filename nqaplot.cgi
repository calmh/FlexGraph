#!/usr/bin/env ruby

require 'lib/gnuplotter'
require 'extractor/nqa'
require 'cgi'

cgi = CGI.new

ids = cgi.params['id'][0].split('p').map { |e| e.split(':').map(&:to_i) }

title = cgi.params['title'][0] || 'NQA results'

if cgi.params.include? 'secs'
  secs = cgi.params['secs'][0].to_i
else
  secs = 86400
end

handle_ids = ids[0]

t = PlotTheme.new
t.line_width = 1
t.line_colors << "#eb690b"
t.line_colors << "#00a0e1"
t.line_colors << "#97bf0d"
t.line_colors << "#ff0000"
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
p.title = title if !title.nil?
p.width = 640
p.height = 280

l1 = PlotLine.new
l1.title = "Min RTT"
l1.unit = "ms"
l1.use_long_title = true
l2 = PlotLine.new
l2.title = "Median RTT"
l2.unit = "ms"
l2.use_long_title = true
l3 = PlotLine.new
l3.title = "Max RTT"
l3.unit = "ms"
l3.use_long_title = true
l4 = PlotLine.new
l4.title = "Loss"
l4.unit = "%"
l4.use_long_title = true

ex = NQAExtractor.new
admin_id, tag_id = handle_ids
rows = ex.nqa_data admin_id, tag_id, secs
rows.each do |time, loss, min, med, max|
  l1 << [ time, min ]
  l2 << [ time, med ]
  l3 << [ time, max ]
  l4 << [ time, loss ]
end
p << l1
p << l2
p << l3
p << l4

puts "Content-type: image/png\n\n"
puts p.png

