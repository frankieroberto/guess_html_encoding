# encoding: UTF-8
require 'spec_helper'

describe "GuessHtmlEncoding" do
  describe "#guess" do
    it "can use headers" do
      guess = GuessHtmlEncoding.guess("<html><body><div>hi!</div></body></html>",
                                      "Hello: world\nContent-Type: text/html; charset=LATIN1\nFoo: bar")
      expect(guess).to eq("ISO-8859-1")
    end

    it "accepts headers as a hash as well" do
      guess = GuessHtmlEncoding.guess("<html><body><div>hi!</div></body></html>",
          {"Hello" => "world", "Content-Type" => "text/html; charset=LATIN1", "Foo" => "bar"})
      expect(guess).to eq("ISO-8859-1")
    end

    it "accepts meta tags" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=LATIN1"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("ISO-8859-1")
    end

    it "works okay when there is a semi-colon after the encoding with headers" do
      guess = GuessHtmlEncoding.guess("<html><body><div>hi!</div></body></html>",
                                      "Hello: world\nContent-Type: text/html; charset=utf-8;\nFoo: bar")
      expect(guess).to eq("UTF-8")
    end

    it "works okay when there is a semi-colon after the encoding with meta-tags" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=utf-8;"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("UTF-8")
    end

    it "converts UTF8 to UTF-8" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=utf8;"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("UTF-8")
    end

    it "converts CP-1251 to CP1251" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=cp-1251;"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("CP1251")
    end

    it "skips the header content type if it's invalid" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=utf8;"></head><body><div>hi!</div></body></html>',
                                      "Hello: world\nContent-Type: text/html; charset=RU;\nFoo: bar")
      expect(guess).to eq("UTF-8")
    end

    it "translates WIN1251 to WINDOWS-1250" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=WIN1251;"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("WINDOWS-1250")
    end

    it "translates GB2312 to GB18030" do
      guess = GuessHtmlEncoding.guess('<html><head><meta http-equiv="content-type" content="text/html; charset=GB2312;"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("GB18030")
    end
    
    it "should not raise an exception if data is nil" do
      expect { GuessHtmlEncoding.guess(nil) }.not_to raise_error
    end
  end

  describe "#encode" do
    it "should work on correctly encoded pages" do
      data = "<html><head><meta http-equiv='content-type' content='text/html; charset=utf8;'></head><body><div>hi!♥</div></body></html>"
      data.force_encoding("ASCII-8BIT")
      expect(data).to be_valid_encoding # everything is valid in binary

      expect(GuessHtmlEncoding.guess(data)).to eq("UTF-8") # because the page says so!
      expect(data.force_encoding("UTF-8")).to be_valid_encoding # because it really is utf-8

      encoded = GuessHtmlEncoding.encode(data)
      expect(encoded.encoding.to_s).to eq("UTF-8")
      expect(encoded).to be_valid_encoding
    end

    it "should work on incorrectly encoded pages" do
      data = "<html><head><meta http-equiv='content-type' content='text/html; charset=utf8;'></head><body><div>hi!\xc2</div></body></html>"
      data.force_encoding("ASCII-8BIT")
      expect(data).to be_valid_encoding # everything is valid in binary

      expect(GuessHtmlEncoding.guess(data)).to eq("UTF-8") # because the page says so!
      expect(data.force_encoding("UTF-8")).not_to be_valid_encoding # because of the bad byte sequence \xc2 which is not valid UTF-8

      encoded = GuessHtmlEncoding.encode(data)
      expect(encoded.encoding.to_s).to eq("UTF-8")
      expect(encoded).to be_valid_encoding
    end

    it "should work on pages encoded with an unknown encoding by forcing them to utf8" do
      data = "<html><head><meta http-equiv='content-type' content='text/html; charset=x-mac-roman;'></head><body><div>hi!</div></body></html>"
      data.force_encoding("ASCII-8BIT")
      expect(data).to be_valid_encoding # everything is valid in binary

      expect(GuessHtmlEncoding.guess(data)).to eq("X-MAC-ROMAN") # because the page says so!

      encoded = GuessHtmlEncoding.encode(data)
      expect(encoded.encoding.to_s).to eq("UTF-8")
      expect(encoded).to be_valid_encoding

      expect(data.encoding.to_s).to eq("ASCII-8BIT")
    end

    it "should not raise an exception if data is nil" do
      expect { GuessHtmlEncoding.encode(nil) }.not_to raise_error
    end

    it "should work on GB18030 (and translate GB2312 into GB18030)" do
      data = File.read(File.join(File.dirname(__FILE__), "fixtures/gb18030.html"), :encoding => "binary")
      expect(GuessHtmlEncoding.encoding_loaded?("GB18030")).to be_truthy
      expect(GuessHtmlEncoding.guess(data)).to eq("GB18030")
      expect(GuessHtmlEncoding.encode(data).encoding.to_s).to eq("GB18030")
    end
    
    it "should work with headers as a hash" do
      data = File.read(File.join(File.dirname(__FILE__), "fixtures/gb18030.html"), :encoding => "binary")
      expect(lambda { GuessHtmlEncoding.encode(data, {}) }).not_to raise_error
    end
  end

  describe "#encoding_loaded?" do
    it 'returns true for all loaded encodings' do
      (Encoding.name_list - ["internal"]).each do |name|
        expect(GuessHtmlEncoding.encoding_loaded?(name)).to be_truthy
        expect { Encoding.find(name) }.not_to raise_error
      end
    end

    it 'returns true for uppercase encodings' do
      expect(GuessHtmlEncoding.encoding_loaded?("WINDOWS-1250")).to be_truthy
      expect { Encoding.find("WINDOWS-1250") }.not_to raise_error
    end

    it 'returns true for lowercase encodings' do
      expect(GuessHtmlEncoding.encoding_loaded?("windows-1250")).to be_truthy
      expect { Encoding.find("windows-1250") }.not_to raise_error
    end

    it 'returns true for encoding aliases' do
      Encoding.aliases.keys.each do |key|
        expect(GuessHtmlEncoding.encoding_loaded?(key)).to be_truthy
        expect(GuessHtmlEncoding.encoding_loaded?(key.upcase)).to be_truthy
        expect { Encoding.find(key) }.not_to raise_error
        expect { Encoding.find(key.upcase) }.not_to raise_error
      end
    end

    it 'returns false for irregular or unloaded encoding' do
      expect(GuessHtmlEncoding.encoding_loaded?('_WHY')).to be_falsy
    end

    it "accepts a simple meta tag" do
      # Like http://www.taobao.com
      guess = GuessHtmlEncoding.guess('<html><head><meta charset="gbk" /></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("GBK")
    end

    it "works as well when there is no double quotation marks with http-equiv in meta-tags" do
      # Like http://www.frozentux.net/iptables-tutorial/cn/iptables-tutorial-cn-1.1.19.html
      guess = GuessHtmlEncoding.guess('<html><head><META http-equiv=Content-Type content="text/html; charset=utf-8"></head><body><div>hi!</div></body></html>')
      expect(guess).to eq("UTF-8")
    end
  end
end
