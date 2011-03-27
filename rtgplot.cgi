#!/usr/bin/env ruby

require 'gnuplotter'
require 'rtgextractor'
require 'cgi'

cgi = CGI.new

ids = cgi.params['id'][0].split('p').map { |e| e.split(':').map(&:to_i) }

title = cgi.params['title'][0]

if cgi.params.include? 'secs'
  secs = cgi.params['secs'][0].to_i
else
  secs = 86400
end

handle_ids = ids[0]

t = PlotTheme.new
t.line_width = 1
t.line_colors << "#00a0e1"
t.line_colors << "#eb690b"
t.line_colors << "#97bf0d"
t.line_colors << "#ff0000"
#t.line_colors << "#b5007c"
t.line_style = "fsteps"
t.background_color = "#ffffff"
t.plot_background_color = "#202020"
t.primary_grid_color = "#000000"
t.secondary_grid_color = "#505050"

p = Plot.new
p.theme = t
p.title = title if !title.nil?
p.width = 640
p.height = 280
p.font_face = "ttf-liberation/LiberationMono-Regular"
p.font_size = 8
p.title_font_face = "ttf-liberation/LiberationSans-Bold"
p.title_font_size = 11

router_id, interface_id = handle_ids

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
in_t, out_t = ex.traffic_data(router_id, interface_id, secs)
in_t.each { |d| l1 << d }
out_t.each { |d| l2 << d }

p << l1
p << l2

hostname = ex.router_name(router_id)
interface_name, interface_descr = ex.interface_name_descr(router_id, interface_id)
p.title = "#{hostname} #{interface_name} (#{interface_descr})" if p.title.nil?

puts "Content-type: image/png\n\n"
puts p.png

