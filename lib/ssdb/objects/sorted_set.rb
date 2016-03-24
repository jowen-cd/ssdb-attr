#
# Class SortedSet provides <description>
#
# @author Larry Zhao <larry@jianshu.com>
#
module SSDB
  module Objects
    class SortedSet
      def initialize(key)
        @key = key
      end

      def add(name, score)
        call(:zset, @key, name, score)
      end

      def score(name)
        SSDBAttr.pool.with do |conn|
          conn.zscore(@key, name)
        end
      end

      def clear
        SSDBAttr.pool.with do |conn|
          conn.zclear(@key)
        end
      end

      def count
        SSDBAttr.pool.with do |conn|
          conn.zcard(@key)
        end
      end

      def all
        call(:zrange, @key, 0, -1)
      end

      def incr(name, delta=1)
        call(:zincr, @key, name, delta)
      end

      def rebuild_with(array)
        SSDBAttr.pool.with do |conn|
          conn.zclear(@key)

          array.each_with_index do |item, index|
            conn.call_ssdb(:zset, @key, item, index)
          end
        end
      end

      def call(command, *args)
        SSDBAttr.pool.with do |conn|
          conn.call_ssdb(command, *args)
        end
      end
    end
  end
end
