module SSDB
  class SortedSet
    def initialize(key)
      @key = key
    end

    def clear
      call(:zclear, @key)
    end

    def range(offset, limit)
      call(:zrange, @key, offset, limit)
    end

    def incr(name, delta=1)
      call(:zincr, @key, name, delta)
    end

    def set(name, score)
      call(:zset, @key, name, score)
    end

    def call(command, *args)
      SSDBAttr.pool.with do |conn|
        conn.call_ssdb(command, *args)
      end
    end

  end
end
