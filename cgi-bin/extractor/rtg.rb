require 'mysql'
require 'date'
require 'yaml'

class RTGExtractor
  def gauge(table, ids, secs)
    averaged_rate table, ids[0], ids[1], secs, period_for_secs(secs)
  end

  def traffic_data_added(ids, secs)
    data_added ids, secs, [ 'ifInOctets' ], [ 'ifOutOctets' ]
  end

  def traffic_packets_added(ids, secs)
    data_added ids, secs, [ 'ifHCInMulticastPkts', 'ifInNUcastPkts', 'ifInUcastPkts' ], [ 'ifHCOutMulticastPkts', 'ifOutNUcastPkts', 'ifOutUcastPkts' ]
  end

  def data_added(ids, secs, in_tables, out_tables)
    data = []
    data[0] = nil
    data[1] = nil

    tables = [ in_tables, out_tables ]
    [ 0, 1 ].each do |i|
      tables[i].each do |table|
        ids.each do |rid, iid|
          begin
            new_data = averaged_rate table, rid, iid, secs, period_for_secs(secs)
            if data[i].nil?
              data[i] = new_data
            else
              data[i] = tsmerge data[i], new_data
              data[i] = data[i].map { |x| [ x[0], x[1] + x[2] ] }
            end
          rescue
            # Ignore failures in getting data from db
          end
        end
      end
    end

    return tsmerge data[0], data[1]
  end

  def traffic_data(rid, iid, secs)
    in_octets = averaged_rate "ifInOctets", rid, iid, secs, period_for_secs(secs)
    out_octets = averaged_rate "ifOutOctets", rid, iid, secs, period_for_secs(secs)
    return tsmerge in_octets, out_octets
  end

  def averaged_rate(table, rid, iid, secs, interval)
    start = Time.now.to_i - secs
    rows = []
    db_tz = conf['db_timezone']
    disp_tz = conf['display_timezone']
    res = connection.query "SELECT (CAST(UNIX_TIMESTAMP(CONVERT_TZ(dtime, '#{db_tz}', '#{disp_tz}')) / #{interval.to_i} AS SIGNED)) * #{interval.to_i} AS avgtime, AVG(rate) FROM #{table}_#{rid} WHERE id = #{iid.to_i} AND dtime > FROM_UNIXTIME(#{start.to_i}) GROUP BY avgtime ORDER BY avgtime"
    res.each { |r| rows << [ r[0].to_i, r[1].to_i ]}
    return rows
  end

  def router_name(router_id)
    res = connection.query "SELECT name FROM router WHERE rid = #{router_id.to_i}"
    if res.num_rows == 1
      row = res.fetch_row
      return row[0].to_s
    end
    return nil
  end

  def interface_name_descr(router_id, interface_id)
    res = connection.query "SELECT name, description FROM interface WHERE rid = #{router_id.to_i} AND id = #{interface_id.to_i}"
    if res.num_rows == 1
      row = res.fetch_row
      return [ row[0].to_s, row[1].to_s ]
    end
    return nil
  end

  def list_routers
    res = connection.query "SELECT name, rid FROM router ORDER BY name"
    routers = []
    res.each do |row|
      routers << { :name => row[0], :rid => row[1].to_i }
    end
    return routers
  end

  def list_interfaces(rid)
    res = connection.query "SELECT id, name, status, description, speed FROM interface WHERE rid = #{rid} ORDER BY name, description"
    interfaces = []
    res.each do |row|
      interfaces << { :id => row[0].to_i, :name => row[1], :status => row[2], :description => row[3], :speed => row[4].to_i }
    end
    return interfaces
  end

  def connection
    @connection ||= Mysql::new conf['host'], conf['user'], conf['pass'], conf['database']
  end

  def conf
    @conf ||= YAML.load_file('rtgextractor.cfg')
  end

  def period_for_secs(secs)
    desired_datapoints = conf['desired_datapoints']
    intervals = conf['averaging_intervals']
    intervals.each do |interval|
      return interval if secs < interval * desired_datapoints
    end
    return intervals.last
  end

  def tsmerge(ts1, ts2)
    l1 = ts1.length
    l2 = ts2.length
    i1 = 0
    i2 = 0
    ts = []
    while i1 < l1 && i2 < l2
      t1 = ts1[i1][0]
      t2 = ts2[i2][0]
      if t1 == t2
        ts << [ t1, ts1[i1][1], ts2[i2][1] ]
        i1 += 1
        i2 += 1
      elsif t1 < t2
        ts << [ t1, ts1[i1][1], 0 ]
        i1 += 1
      else
        ts << [ t2, 0, ts2[i2][1] ]
        i2 += 1
      end
    end
    ts += ts1[i1..-1].map { |t, v| [ t, v, 0 ] }
    ts += ts2[i2..-1].map { |t, v| [ t, 0, v ] }
    return ts
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'test/unit'
  class TestExtractor < Test::Unit::TestCase
    def setup
      @ex = RTGExtractor.new
    end

    def test_tsmerge_should_merge_1
      ts1 = [ [ 10, 100 ], [ 20, 150 ] ]
      ts2 = [ [ 10, 200 ], [ 20, 250 ] ]
      ts = @ex.tsmerge ts1, ts2
      assert_equal [ [ 10, 100, 200 ], [ 20, 150, 250 ] ], ts
    end

    def test_tsmerge_should_merge_2
      ts1 = [ [ 10, 100 ], [ 15, 150 ], [ 30, 300 ] ]
      ts2 = [ [ 10, 200 ], [ 20, 250 ], [ 30, 350 ] ]
      ts = @ex.tsmerge ts1, ts2
      assert_equal [ [ 10, 100, 200 ], [ 15, 150, 0 ], [ 20, 0, 250], [ 30, 300, 350 ] ], ts
    end

    def test_tsmerge_should_merge_3
      ts1 = [ [ 10, 100 ], [ 30, 300 ] ]
      ts2 = [ [ 10, 200 ], [ 20, 250 ], [ 30, 350 ] ]
      ts = @ex.tsmerge ts1, ts2
      assert_equal [ [ 10, 100, 200 ], [20, 0, 250 ], [ 30, 300, 350 ] ], ts
    end

    def test_tsmerge_should_merge_4
      ts1 = [ [ 10, 100 ], [ 20, 250 ], [ 30, 300 ] ]
      ts2 = [ [ 10, 200 ], [ 30, 350 ] ]
      ts = @ex.tsmerge ts1, ts2
      assert_equal [ [ 10, 100, 200 ], [ 20, 250, 0 ], [ 30, 300, 350 ] ], ts
    end

    def test_tsmerge_should_merge_5
      ts1 = [ [ 10, 100 ], [ 20, 250 ], [ 30, 300 ] ]
      ts2 = [ ]
      ts = @ex.tsmerge ts1, ts2
      assert_equal [ [ 10, 100, 0 ], [ 20, 250, 0 ], [ 30, 300, 0 ] ], ts
    end
  end
end

