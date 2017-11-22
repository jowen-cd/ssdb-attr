require "spec_helper"

describe SSDB::Type::JSON do
  describe ".inititalize" do
    context "valid data type" do
      it "hash" do 
        xx = SSDB::Type::JSON.new({:a => 1})
        expect(xx.instance_variable_get(:@val)).to eq(:a => 1)
      end

      it "array" do
        xx = SSDB::Type::JSON.new(1.upto(10).to_a)
        expect(xx.instance_variable_get(:@val)).to eq(1.upto(10).to_a)
      end
    end

    context "invalid data type" do
      it do 
        xx = SSDB::Type::JSON.new(11)
        expect(xx.instance_variable_get(:@val)).to be_nil

        xx = SSDB::Type::JSON.new("abc")
        expect(xx.instance_variable_get(:@val)).to be_nil
      end
    end
  end

  describe ".encode" do
    it do
      xx = SSDB::Type::JSON.new(11)
      expect(xx.encode).to be_nil
      xx = SSDB::Type::JSON.new("abc")
      expect(xx.encode).to be_nil

      xx = SSDB::Type::JSON.new([1])
      expect(xx.encode).to eq([1].to_json)

      xx = SSDB::Type::JSON.new(:a => 1)
      expect(xx.encode).to eq({:a => 1}.to_json)
    end
  end

  describe "#decode" do
    context "decode blank string" do
      it do
        expect(SSDB::Type::JSON.decode("")).to be_nil
      end
    end

    context "decode invalid data type json" do
      it do
        str = ActiveSupport::JSON.encode(1)
        expect(SSDB::Type::JSON.decode(str)).to be_nil

        str = ActiveSupport::JSON.encode("abc")
        expect(SSDB::Type::JSON.decode(str)).to be_nil
      end
    end

    context "decode valid data type" do
      it "hash" do
        expect(SSDB::Type::JSON.decode(:a => 1)).to eq(:a => 1)
      end

      it "array" do
        expect(SSDB::Type::JSON.decode([1, 2])).to eq([1, 2])
      end
    end

    context "decode valid data type json" do
      it do
        str = [1, 2].to_json
        expect(SSDB::Type::JSON.decode(str)).to eq([1, 2])

        str = {:a => 2}.to_json
        expect(SSDB::Type::JSON.decode(str)).to eq("a" => 2)
      end
    end
  end
end
