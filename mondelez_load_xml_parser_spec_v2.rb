require 'spec_helper'


describe FourKitesParsers::Parser::MondelezLoadXmlParserV2 do

  before do
    allow(FourKitesCommon::Logger).to receive(:warn)
    allow(SettingsUtil).to receive(:enabled?).and_return false

  end

  let!(:mondelez_1) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_base.xml')
  parser.parse_file.first}
  let!(:mondelez_2) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_base_one_AA.xml')
  parser.parse_file.first}
  let!(:mondelez_3) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_base_two_AA.xml')
  parser.parse_file.first}

  let!(:mondelez_4) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_base_one_AB.xml')
  parser.parse_file.first}
  let!(:mondelez_5) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_base_two_AB.xml')
  parser.parse_file.first}

  let!(:mondelez_7) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_base_delete.xml')
  parser.parse_file.first}

  let!(:mondelez_8) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_no_appt_times.xml')
  parser.parse_file.first}

  let!(:mondelez_9) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test1.xml')
  parser.parse_file.first}
  let!(:mondelez_10) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test2.xml')
  parser.parse_file.first}
  let!(:mondelez_11) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test_file_1.xml')
  parser.parse_file.first}
  let!(:mondelez_12) {parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test_file_2.xml')
  parser.parse_file.first}

  context 'Mondelez' do
    it 'parses base information' do
      expect(mondelez_1[0..32]).to eq ["add",
                                       "5025242810",
                                       "CACG",
                                       [{:reference_numbers => ["BM#:5025242810", "5726:TEST:GREEN ROAD DC:EAST:DC"],
                                         :location => "GREEN ROAD ON DC",
                                         :location_id => "385387",
                                         :address_line_1 => "400 GREEN RD-EAST BUILDIN",
                                         :city => "STONEY CREEK",
                                         :state => "ON",
                                         :postal => "L8E 2B4",
                                         :country => "CA",
                                         :latitude => "43.23401",
                                         :longitude => "-79.7277",
                                         :sequence => "1",
                                         :customer => {id: "385387"},
                                         :want_time => "Fri, 26 Jan 2018 11:03:48.000000000 +0000",
                                         :arrival_time => DateTime.parse('2018-01-26 10:00:00')}],
                                       [{:reference_numbers => ["BM#:5025242810", "384:BRAMPTON DC:EAST:VF"],
                                         :location => "BDC - BRAMPTON DC",
                                         :location_id => "683950",
                                         :address_line_1 => "255 CHRYSLER DRIVE UNIT 1",
                                         :city => "BRAMPTON",
                                         :state => "ON",
                                         :postal => "L6S 6C8",
                                         :country => "CA",
                                         :latitude => "43.74518",
                                         :longitude => "-79.70909",
                                         :sequence => "2",
                                         :customer => {id: "683950"},
                                         :want_time => "Sat, 27 Jan 2018 00:00:00.000000000 +0000",
                                         :arrival_time => DateTime.parse('2018-01-27 08:30:00')}],
                                       ["SNACKS",
                                        "FOODSERVICE",
                                        "STO",
                                        "5726",
                                        "TEST",
                                        "GREEN ROAD DC",
                                        "EAST",
                                        "DC",
                                        "384",
                                        "BRAMPTON DC",
                                        "VF"],
                                       nil,
                                       nil,
                                       ["ShipmentGid DomainName: KRAFT/KFNA",
                                        "GLOG Refnum: KRAFT/KFNA.5025242810",
                                        "Loadtype Drop Or Live: D",
                                        "High Commodity: UNPROTECTED",
                                        "Business Unit:CANADA",
                                        "7821255515"],
                                       nil,
                                       nil,
                                       "5025242810",
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       nil,
                                       []]
    end


    it 'parses base load add/delete information' do
      expect(mondelez_7[0]).to eq "delete"
    end

    it 'handles single AA' do
      expect(mondelez_2[3].first[:arrival_time]).to eq DateTime.parse('2018-01-05 20:00:00')
    end

    it 'handles double AA' do
      expect(mondelez_3[3].first[:arrival_time]).to eq DateTime.parse('2017-01-03 22:00:00')
    end

    it "should map location id from location ref tag" do
      expect(mondelez_9[3].first[:location_id]).to eq "0384"
    end

    it "should map address_line from location address field" do
      expect(mondelez_9[3].first[:address_line_1]).to eq "255 CHRYSLER DR, UNIT 1"
    end

    it "should map the latitude and longitude from location address field" do
      expect(mondelez_9[3].first[:latitude]).to eq "43.73902"
      expect(mondelez_9[3].first[:longitude]).to eq "-79.7014"
    end

    it "should map the refernce with GLOG prefix" do
      expect(mondelez_9[8].include?("GLOG Refnum: M01/NAM.7000005607")).to eq true
    end

    it "should not map the glog ref num if the path is absent" do
      expect(mondelez_10[8]).to eq ["ShipmentGid DomainName: M01/NAM", "High Commodity: CONDITIONED", "Loadtype Drop Or Live: D", "Business Unit:CANADA", "2701474506"]
    end

    it "should not map the address line if the location path location id does not match with shipmentStop location id" do
      expect(mondelez_10[3].first[:location_id]).to eq "not_equal"
      expect(mondelez_10[3].first[:address_line_1]).to be_nil
    end

    it "should contain live or drop reference number present in the load" do
      expect(mondelez_11[8].include?("Loadtype Drop Or Live: D")).to eq(true)
    end

    it "should not conatin sku number in the reference_numbers" do
      expect(mondelez_11[8].include?("10")).to eq(false)
    end

    it "should not contain the live or drop load type ref number if the field is balnk" do
      expect(mondelez_12[8].include?("Loadtype Drop Or Live: D")).to eq(false)
    end
  end

  describe "parse_shipment_address" do
    let!(:xml_doc) {xml_doc = Nokogiri::XML(File.read("spec/input_files/mondelez_load_xml_test1.xml")) do |config|
      config.strict.noblanks
    end
    shipment = xml_doc.children.first
    }

    it "should map the address from location address field" do
      stop = {:location_id => "0384"}
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test2.xml')
      parser.send(:parse_shipment_address, xml_doc.xpath("./TransmissionBody").children.first.xpath("./PlannedShipment").children.first, stop)
      expect(stop).to eq({:location_id => "0384", :address_line_1 => "255 CHRYSLER DR, UNIT 1", :city => "BRAMPTON", :state => "ON", :postal => "L6S 6C8", :country => "CA", :latitude => "43.73902", :location => "BRAMPTON ON", :longitude => "-79.7014"})
    end

    it "should not map the address from location address field if the location id does not match" do
      stop = {:location_id => "038"}
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test2.xml')
      parser.send(:parse_shipment_address, xml_doc.xpath("./TransmissionBody").children.first.xpath("./PlannedShipment").children.first, stop)
      expect(stop).to eq({:location_id => "038"})
    end
  end


  describe "parse_location_id" do
    let!(:shipment) {
      xml = <<-XML
      <ShipmentStop>
      <LocationRef>
      <TransactionCode>NP</TransactionCode>
      <LocationGid>
      <Gid>
      <DomainName>M01</DomainName>
      <Xid>0348</Xid>
      </Gid>
      </LocationGid>
      <LocationName>CARAVAN LOGISTICS INC</LocationName>
      </LocationRef>
      </ShipmentStop>
      XML
      xml_doc = Nokogiri::XML(xml) do |config|
        config.strict.noblanks
      end
      shipment = xml_doc.children
    }

    let!(:shipment1) {
      xml = <<-XML
      <ShipmentStop>
      <LocationRef>
      <TransactionCode>NP</TransactionCode>
      <LocationName>CARAVAN LOGISTICS INC</LocationName>
      </LocationRef>
      </ShipmentStop>
      XML
      xml_doc = Nokogiri::XML(xml) do |config|
        config.strict.noblanks
      end
      shipment = xml_doc.children
    }

    it "should map the location id from location ref field" do
      stop = {}
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test2.xml')
      parser.send(:parse_location_id, shipment, stop)
      expect(stop[:location_id]).to eq("0348")
    end

    it "should map the location id from location ref field" do
      stop = {}
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_load_xml_test2.xml')
      parser.send(:parse_location_id, shipment1, stop)
      expect(stop[:location_id]).to eq(nil)
    end
  end

  describe "#removed strict from Nokogiri configuration" do
    it "should not raise error when parsing a file that contain &rsquo and &nbsp" do
      expect(Nokogiri::XML).not_to receive(:SyntaxError)
      allow(FourKitesParsers::Parser::MondelezLoadXmlParserV2).to receive(:strict_enabled?).and_return false
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/MondelezLoadXml.xml')
      result = parser.parse_file.first
    end
  end


  describe "parse_customer_id" do
    let!(:xml_doc) {xml_doc = Nokogiri::XML(File.read("spec/input_files/mondelez_customer_mapping.xml")) do |config|
      config.strict.noblanks
    end
    shipment = xml_doc.children.first
    }
    it "should map the customer id" do
      stop = {:location_id => "0384"}
      location_ref_num = "0200158167"
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_customer_mapping.xml')
      parser.send(:parse_customer_id, location_ref_num, xml_doc.xpath("./TransmissionBody").children.first.xpath("./PlannedShipment").children.first, stop)
      expect(stop).to eq({:location_id => "0384", :customer => {:id => "US4000311"}})
    end
  end

  describe '#check strict enabled' do
    it "checkout for strict enabled" do
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_customer_mapping.xml')
      expect(SettingsUtil).to receive(:enabled?).and_return true
      parser.parse_file
    end

    it "should return false if exception occured" do
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_customer_mapping.xml')
      expect(SettingsUtil).to receive(:enabled?).and_raise(:error)
      expect(FourKitesCommon::Logger).to receive(:warn)
      parser.parse_file
    end
  end


  describe '#check expection in parse_shipment' do
    it "should throw exception" do
      parser = FourKitesParsers::Parser::MondelezLoadXmlParserV2.new('spec/input_files/mondelez_customer_mapping.xml')
      expect(FourKitesCommon::Logger).to receive(:error)
      parser.parse_shipment
    end
  end
end
