# require 'spec_helper'
require "ssdb-attr"

describe SSDBAttr do

  describe ".pool" do
    context "with only one pool" do
      it "should set it up as default pool if no name specified" do
        options = { :url => "redis://localhost:8888" }

        SSDBAttr.setup(options)
        expect(SSDBAttr.default_pool_name).to eq(:default)
        expect(SSDBAttr.pools.keys).to match_array([:default])

        pool_dbl = double(ConnectionPool)
        expect(SSDBAttr.pools).to receive(:[]).with(:default).and_return(pool_dbl)
        expect(SSDBAttr.default_pool).to eq(pool_dbl)
      end

      it "should fetch the named pool if a connection name is passed" do
        options = { :url => "redis://localhost:8888", :name => "foobar" }

        SSDBAttr.setup(options)
        expect(SSDBAttr.default_pool_name).to eq(:foobar)
        expect(SSDBAttr.pools.keys).to match_array([:foobar])

        pool_dbl = double(ConnectionPool)

        expect(SSDBAttr.pools).to receive(:[]).with(:foobar).and_return(pool_dbl)
        expect(SSDBAttr.pool(:foobar)).to eq(pool_dbl)

        expect(SSDBAttr.pools).to receive(:[]).with(:foobar).and_return(pool_dbl)
        expect(SSDBAttr.default_pool).to eq(pool_dbl)
      end
    end

    context "with more than one pools" do
      it "should set it up as default pool correctly" do
        options = [
          { :url => "redis://localhost:8888", :name => :bar, :default => true },
          { :url => "redis://localhost:8889", :name => "foo" }
        ]

        SSDBAttr.setup(options)
        expect(SSDBAttr.default_pool_name).to eq(:bar)
        expect(SSDBAttr.pools.keys).to match_array([:bar, :foo])

        pool_dbl1 = double(ConnectionPool)
        pool_dbl2 = double(ConnectionPool)

        expect(SSDBAttr.pools).to receive(:[]).with(:bar).and_return(pool_dbl1)
        expect(SSDBAttr.pools).to receive(:[]).with(:foo).and_return(pool_dbl2)

        expect(SSDBAttr.default_pool).to eq(pool_dbl1)
        expect(SSDBAttr.pool(:foo)).to eq(pool_dbl2)
      end

      it "should raise error if no default pool specified" do
        options = [{ :url => "redis://localhost:8888", :name => "foobar" }]
        expect { SSDBAttr.setup(options) }.to raise_error(RuntimeError)
      end

      it "should raise error if more than one pool named as default" do
        options = [
          { :url => "redis://localhost:8888", :name => :bar, :default => true },
          { :url => "redis://localhost:8889", :name => "foo", :default => true }
        ]

        expect { SSDBAttr.setup(options) }.to raise_error(RuntimeError)
      end
    end
  end

  describe "#setup" do
    context "with only one pool" do
      it "should setup a ssdb connection pool with no name specified" do
        options = { :url => "redis://localhost:8888" }

        SSDBAttr.setup(options)

        expect(SSDBAttr.pools.size).to eq(1)
        expect(SSDBAttr.pools[:default]).not_to be_nil
        expect(SSDBAttr.default_pool_name).to eq(:default)
      end

      it "should setup a ssdb connection pool with name specified" do
        options = { :url => "redis://localhost:8888", :name => :main }

        SSDBAttr.setup(options)

        expect(SSDBAttr.pools.size).to eq(1)
        expect(SSDBAttr.default_pool_name).to eq(:main)
        expect(SSDBAttr.pools[:main]).not_to be_nil
        expect(SSDBAttr.default_pool).to eq(SSDBAttr.pools[:main])
      end
    end

    context "with pools" do
      it "should raise error if no name specified" do
        options = [
          { :url => "redis://localhost:8888" },
          { :url => "redis://localhost:6379" }
        ]

        expect { SSDBAttr.setup(options) }.to raise_error(RuntimeError)
      end

      it "should raise error if no default specified" do
        options = [
          { :url => "redis://localhost:8888", :name => :pool1 },
          { :url => "redis://localhost:6379", :name => :pool2 }
        ]

        expect { SSDBAttr.setup(options) }.to raise_error(RuntimeError)
      end

      it "should initialize correctly" do
        options = [
          { :url => "redis://localhost:8888", :name => :ssdb,  :pool_size => 10, :timeout => 2, :default => true },
          { :url => "redis://localhost:6379", :name => :redis, :pool_size => 5,  :timeout => 3 }
        ]

        SSDBAttr.setup(options)

        expect(SSDBAttr.pools.size).to eq(2)
        expect(SSDBAttr.pools[:ssdb]).to be_a(ConnectionPool)
        expect(SSDBAttr.pools[:redis]).to be_a(ConnectionPool)
        expect(SSDBAttr.default_pool_name).to eq(:ssdb)
        expect(SSDBAttr.default_pool).to eq(SSDBAttr.pools[:ssdb])
      end
    end
  end

  describe "#create_pool" do
    it "will use create a connection pool" do
      pool = SSDBAttr.create_pool(:url => "redis://localhost:8888", :pool_size => 10, :timeout => 18)

      expect(pool).not_to be_nil
      expect(pool).to be_a(ConnectionPool)
      expect(pool.instance_variable_get(:@size)).to eq(10)
      expect(pool.instance_variable_get(:@timeout)).to eq(18)

      conn = pool.with { |conn| conn }
      expect(conn).to be_a(Redis)
      expect(conn.client.host).to eq("localhost")
      expect(conn.client.port).to eq(8888)
    end
  end

  describe "#create_conn" do
    context "with url" do
      it do
        conn = SSDBAttr.create_conn(:url => "redis://localhost:8888")

        expect(conn).not_to be_nil
        expect(conn).to be_a(Redis)
        expect(conn.client.host).to eq("localhost")
        expect(conn.client.port).to eq(8888)
      end
    end

    context "with host/port options" do
      it do
        conn = SSDBAttr.create_conn(:host => "localhost", :port => "8888")

        expect(conn).not_to be_nil
        expect(conn).to be_a(Redis)
        expect(conn.client.host).to eq("localhost")
        expect(conn.client.port).to eq(8888)
      end
    end
  end
end
