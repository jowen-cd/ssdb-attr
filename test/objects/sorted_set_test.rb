require 'ssdb-attr'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'

test_framework = defined?(MiniTest::Test) ? MiniTest::Test : MiniTest::Unit::TestCase

require File.expand_path(File.dirname(__FILE__) + "../../../lib/ssdb/objects/sorted_set")

SSDBAttr.setup(url: 'redis://localhost:8888')

class SortedSetTest < test_framework
  def setup
    # Clean up SSDB
    SSDBAttr.pool.with { |conn| conn.zclear(:foo) }
  end

  def test_add_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)
    ss.add(:bar, 1)

    assert_equal 1, SSDBAttr.pool.with { |conn| conn.zscore(:foo, :bar) }
  end

  def test_score_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)
    ss.add(:bar, 2333)

    assert_equal SSDBAttr.pool.with { |conn| conn.zscore(:foo, :bar) }, ss.score(:bar)
  end

  def test_clear_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)
    ss.add(:bar1, 1)
    ss.add(:bar2, 2)

    assert_equal 2, SSDBAttr.pool.with { |conn| conn.zcard(:foo) }

    ss.clear

    assert_equal 0, SSDBAttr.pool.with { |conn| conn.zcard(:foo) }
  end

  def test_count_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)
    ss.add(:bar1, 1)
    ss.add(:bar2, 2)

    assert_equal SSDBAttr.pool.with { |conn| conn.zcard(:foo) }, ss.count

    ss.add(:bar3, 3)

    assert_equal SSDBAttr.pool.with { |conn| conn.zcard(:foo) }, ss.count
  end

  def test_all_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)
    ss.add(:bar1, 1)
    ss.add(:bar2, 2)
    ss.add(:bar3, 3)
    ss.add(:bar4, 4)

    assert_equal ['bar1', 'bar2', 'bar3', 'bar4'].sort, ss.all.sort
  end

  def test_incr_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)

    ss.add(:bar, 1)
    assert_equal 1, SSDBAttr.pool.with { |conn| conn.zscore(:foo, :bar) }

    ss.incr(:bar)
    assert_equal 2, SSDBAttr.pool.with { |conn| conn.zscore(:foo, :bar) }

    ss.incr(:bar, 2)
    assert_equal 4, SSDBAttr.pool.with { |conn| conn.zscore(:foo, :bar) }
  end

  def test_rebuild_with_of_sorted_set
    ss = SSDB::Objects::SortedSet.new(:foo)

    ss.add(:bar, 1)

    SSDBAttr.pool.with do |conn|
      assert_equal 1, conn.zcard(:foo)

      ss.rebuild_with(['a', 'b', 'c', 'd'])

      assert_equal 4, conn.zcard(:foo)

      assert_equal 0, conn.zscore(:foo, :a)
      assert_equal 1, conn.zscore(:foo, :b)
      assert_equal 2, conn.zscore(:foo, :c)
      assert_equal 3, conn.zscore(:foo, :d)
    end
  end
end
