require_relative "spec_helper"

describe Stampr::Mailing do
  before :each do
    Stampr.authenticate "user", "pass"
  end

  let(:mailing_create) { Hash[JSON.parse(json_data("mailing_create")).map {|k, v| [k.to_sym, v]}] }


  describe "#initialize" do
    it "should generate a Batch if it isn't included" do
      Stampr::Batch.should_receive(:new).with().and_return(mock(id: 7))
      subject = described_class.new
      subject.batch_id.should eq 7
    end

    it "should fail with batch & batch_id" do
      ->{ described_class.new batch_id: 2, batch: mock }.should raise_error(ArgumentError, "Must supply :batch_id OR :batch options")
    end

    it "should fail with bad data" do
      ->{ described_class.new batch_id: 2, data: 12 }.should raise_error(TypeError, "bad format for data")
    end

    it "should succeed with a good MD5" do
      described_class.new batch_id: 2, mailing_id: 12, data: "sdf", md5: Digest::MD5.hexdigest("sdf")
    end

    it "should fail with bad MD5" do
      ->{ described_class.new batch_id: 2, mailing_id: 12, data: "sdf", md5: "234234" }.should raise_error(ArgumentError, "MD5 digest does not match data")
    end

    it "should yield itself then mail itself if block is given" do
      yielded = nil
      mailing = described_class.new batch_id: 1 do |m|
        m.should_receive(:mail).with()
        yielded = m
      end
      yielded.should be_a Stampr::Mailing
      yielded.should eq mailing
    end
  end

  describe "#mail" do
    it "should post a mailing request without data" do
      subject = described_class.new batch_id: 2, address: "bleh1", returnaddress: "bleh2"

      request = stub_request(:post, "https://user:pass@testing.dev.stam.pr/api/mailings").
         with(body: {"batch_id"=>"2", "address" => "bleh1", "returnaddress" => "bleh2", "format"=>"none"},
              headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'56', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: json_data("mailing_create"), headers: {})

      subject.status.should be_nil
      subject.mail
      subject.id.should eq 1
      subject.status.should eq :received

      request.should have_been_made
    end

    it "should post a mailing request with json data" do
      data = {"fred" => "savage"}
      subject = described_class.new batch_id: 2, address: "bleh1", returnaddress: "bleh2", data: data

      request = stub_request(:post, "https://user:pass@testing.dev.stam.pr/api/mailings").
         with(body: {"batch_id"=>"2", "address" => "bleh1", "returnaddress" => "bleh2", "format" => "json", "md5"=>"68a20e4c76504a1c2bded1fee2ffc753", "data" => Base64.encode64(data.to_json) },
              headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'128', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: json_data("mailing_create"), headers: {})

      subject.status.should be_nil
      subject.mail
      subject.id.should eq 1
      subject.status.should eq :received

      request.should have_been_made
    end

    it "should post a mailing request with html data" do
      data = "<html>Hello world!</html>"
      subject = described_class.new batch_id: 2, address: "bleh1", returnaddress: "bleh2", data: data

      request = stub_request(:post, "https://user:pass@testing.dev.stam.pr/api/mailings").
         with(body: {"batch_id"=>"2", "address" => "bleh1", "returnaddress" => "bleh2", "format" => "html", "md5"=>"4e93ef6f0ebfd2887752065b17ddd3e2", "data" => Base64.encode64(data) },
              headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'144', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: json_data("mailing_create"), headers: {})

      subject.status.should be_nil
      subject.mail
      subject.id.should eq 1
      subject.status.should eq :received

      request.should have_been_made
    end

    it "should post a mailing with pdf data" do
      data = "%PDF1.4..."
      subject = described_class.new batch_id: 2, address: "bleh1", returnaddress: "bleh2", data: data

      request = stub_request(:post, "https://user:pass@testing.dev.stam.pr/api/mailings").
         with(body: {"batch_id"=>"2", "address" => "bleh1", "returnaddress" => "bleh2", "format" => "pdf", "md5"=>"c40b92002dfdac9ee80136d9cc443a2e", "data" => Base64.encode64(data) },
              headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'121', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: json_data("mailing_create"), headers: {})

      subject.status.should be_nil
      subject.mail
      subject.id.should eq 1
      subject.status.should eq :received

      request.should have_been_made
    end

    it "should fail without an address" do
      data = "%PDF1.4..."
      subject = described_class.new batch_id: 2, returnaddress: "bleh"

      -> { subject.mail }.should raise_error Stampr::APIError, "address required before mailing"
    end

    it "should fail without a return address" do
      data = "%PDF1.4..."
      subject = described_class.new batch_id: 2, address: "bleh"

      -> { subject.mail }.should raise_error Stampr::APIError, "return_address required before mailing"
    end
  end


  describe "#delete" do
    it "should delete the mailing" do
      subject = described_class.new mailing_create

      request = stub_request(:delete, "https://user:pass@testing.dev.stam.pr/api/mailings/1").
         with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: [true].to_json, headers: {})

      subject.delete.should be_nil

      request.should have_been_made
    end

    it "should fail if the mailing isn't created yet" do
      subject = described_class.new batch_id: 2

      -> { subject.delete }.should raise_error Stampr::APIError, "Can't #delete before #create"
    end
  end

  let(:uncreated) { Stampr::Mailing.new batch_id: 1 }
  let(:created) { Stampr::Mailing.new mailing_id: 2, batch_id: 1}
  

  describe "#address=" do
    it "should set the value" do
      uncreated.address = "hello"
      uncreated.address.should eq "hello"
    end

    it "should accept nil" do
      uncreated.address = nil
      uncreated.address.should be_nil
    end

    it "should fail with a bad type" do
      -> { uncreated.address = 12 }.should raise_error(TypeError, "address must be a String")
    end

    it "should fail if the Mailing is already created" do
      -> { created.address = "hello" }.should raise_error(Stampr::ReadOnlyError, "can't modify attribute: address")
    end
  end

  describe "#return_address=" do
    it "should set the value" do
      uncreated.return_address = "hello"
      uncreated.return_address.should eq "hello"
    end

    it "should accept nil" do
      uncreated.return_address = nil
      uncreated.return_address.should be_nil
    end

    it "should fail with a bad type" do
      -> { uncreated.return_address = 12 }.should raise_error(TypeError, "return_address must be a String")
    end

    it "should fail if the Mailing is already created" do
      -> { created.return_address = "hello" }.should raise_error(Stampr::ReadOnlyError, "can't modify attribute: return_address")
    end
  end

  describe "#data=" do
    it "should set the value" do
      uncreated.data = "hello"
      uncreated.data.should eq "hello"
    end

    it "should accept nil" do
      uncreated.data = nil
      uncreated.data.should be_nil
    end

    it "should fail with a bad type" do
      -> { uncreated.data = 12 }.should raise_error(TypeError, "bad format for data")
    end

    it "should fail if the Mailing is already created" do
      -> { created.data = "hello" }.should raise_error(Stampr::ReadOnlyError, "can't modify attribute: data")
    end
  end


  describe "#sync" do
    it "should update the status from the server" do
      data = json_data("mailing_create")
      data['"received"'] = '"render"'

      stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/mailings/#{created.id}").
         with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => data, :headers => {})

      created.instance_variable_set :@status, :received 
      created.status.should eq :received 
      created.sync
      created.status.should eq :render
    end

    it "should fail if the Mailing hasn't been created" do
      -> { uncreated.sync }.should raise_error(Stampr::APIError, "can't sync before creation")
    end
  end


  describe ".[]" do
    let(:batch) { Stampr::Batch.new batch_id: 99, config_id: 12 }

    it "should retreive a specific mailing" do
      request = stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/mailings/1").
         with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: json_data("mailing_index"), headers: {})

      mailing = Stampr::Mailing[1]

      mailing.id.should eq 1
      mailing.status.should eq :received

      request.should have_been_made
    end

    it "should fail with a negative id" do
      -> { Stampr::Mailing[-1] }.should raise_error(ArgumentError, "id should be a positive Integer")
    end

    it "should fail with a bad index" do
      -> { Stampr::Mailing["fred"] }.should raise_error(TypeError, "id should be a positive Integer")
    end

    it "should fail if the mailing doesn't exist" do
      request = stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/mailings/99").
         with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
         to_return(status: 200, body: "[]", headers: {})
         
      -> { Stampr::Mailing[99] }.should raise_error(Stampr::RequestError, "No such mailing: 99")
    end
  end

  describe ".browse" do
    let(:batch) { Stampr::Batch.new batch_id: 99, config_id: 12 }

    context "with range" do
      [Time, DateTime].each do |period_class|
        it "should retrieve a list over a #{period_class} period" do
          requests = [0, 1, 2].map do |i|
            stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/mailings/browse/1900-01-01T00:00:00Z/2000-01-01T00:00:00Z/#{i}").
               with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
               to_return(status: 200, body: json_data("mailings_#{i}"), headers: {})
          end

          from, to = period_class.new(1900, 1, 1, 0, 0, 0, "+00:00"), period_class.new(2000, 1, 1, 0, 0, 0, "+00:00")
          mailings = Stampr::Mailing.browse from..to

          mailings.map(&:id).should eq [1, 2, 3]

          requests.each {|request| request.should have_been_made }
        end
      end

      it "should fail with a bad range" do
        -> { Stampr::Mailing.browse 1..3 }.should raise_error(TypeError, "period should be a Range of Time/DateTime")
      end

      it "should fail with a bad range type" do
        -> { Stampr::Mailing.browse 4 }.should raise_error(TypeError, "period should be a Range of Time/DateTime")
      end
    end

    context "with range & batch" do
      [Time, DateTime].each do |period_class|
        it "should retrieve a list of mailings over a #{period_class} period with given status" do
          requests = [0, 1, 2].map do |i|
            stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/batches/99/browse/1900-01-01T00:00:00Z/2000-01-01T00:00:00Z/#{i}").
               with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
               to_return(status: 200, body: json_data("mailings_#{i}"), headers: {})
          end

          from, to = period_class.new(1900, 1, 1, 0, 0, 0, "+00:00"), period_class.new(2000, 1, 1, 0, 0, 0, "+00:00")
          mailings = Stampr::Mailing.browse from..to, batch: batch

          mailings.map(&:id).should eq [1, 2, 3]

          requests.each {|request| request.should have_been_made }
        end
      end

      it "should fail with a bad batch" do
        -> { Stampr::Mailing.browse Time.new(1900, 1, 1, 0, 0, 0, "+00:00")..Time.new(2000, 1, 1, 0, 0, 0, "+00:00"), batch: -1 }.should raise_error(TypeError, ":batch option should be a Stampr::Batch")
      end

      it "should fail with a bad range" do
        -> { Stampr::Mailing.browse 1..3, batch: batch }.should raise_error(TypeError, "period should be a Range of Time/DateTime")
      end
    end

    context "with range & status" do
      [Time, DateTime].each do |period_class|
        it "should retrieve a list of mailings over a #{period_class} period with given status" do
          requests = [0, 1, 2].map do |i|
            stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/mailings/with/processing/1900-01-01T00:00:00Z/2000-01-01T00:00:00Z/#{i}").
               with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
               to_return(status: 200, body: json_data("mailings_#{i}"), headers: {})
          end

          from, to = period_class.new(1900, 1, 1, 0, 0, 0, "+00:00"), period_class.new(2000, 1, 1, 0, 0, 0, "+00:00")
          mailings = Stampr::Mailing.browse from..to, status: :processing

          mailings.map(&:id).should eq [1, 2, 3]

          requests.each {|request| request.should have_been_made }
        end
      end

      it "should fail with a bad status type" do
        period = Time.new(1900, 1, 1, 0, 0, 0, "+00:00")..Time.new(2000, 1, 1, 0, 0, 0, "+00:00")
        -> { Stampr::Mailing.browse period, status: 12 }.should raise_error(TypeError, ":status option should be one of :received, :render, :error, :queued, :assigned, :processing, :printed, :shipped")
      end

      it "should fail with a bad status symbol" do
        period = Time.new(1900, 1, 1, 0, 0, 0, "+00:00")..Time.new(2000, 1, 1, 0, 0, 0, "+00:00")
        -> { Stampr::Mailing.browse period, status: :frog }.should raise_error(ArgumentError, ":status option should be one of :received, :render, :error, :queued, :assigned, :processing, :printed, :shipped")
      end

      it "should fail with a bad range" do
        -> { Stampr::Mailing.browse 1..3, status: :processing }.should raise_error(TypeError, "period should be a Range of Time/DateTime")
      end
    end

    context "with range, status & batch" do
      [Time, DateTime].each do |period_class|
        it "should retrieve a list of mailings over a #{period_class} period with given status" do
          requests = [0, 1, 2].map do |i|
            stub_request(:get, "https://user:pass@testing.dev.stam.pr/api/batches/99/with/processing/1900-01-01T00:00:00Z/2000-01-01T00:00:00Z/#{i}").
               with(headers: {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
               to_return(status: 200, body: json_data("mailings_#{i}"), headers: {})
          end

          from, to = period_class.new(1900, 1, 1, 0, 0, 0, "+00:00"), period_class.new(2000, 1, 1, 0, 0, 0, "+00:00")
          mailings = Stampr::Mailing.browse from..to, status: :processing, batch: batch

          mailings.map(&:id).should eq [1, 2, 3]

          requests.each {|request| request.should have_been_made }
        end
      end
    end
  end
end