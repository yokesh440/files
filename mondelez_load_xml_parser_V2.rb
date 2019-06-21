module FourKitesParsers
  module Parser
    class MondelezLoadXmlParserV2 < KraftLoadXmlParserV2
      include FourKitesParsers::Parser::ParserCommon
      # include FourKitesParsers::Helper::OtmHelpers::KraftOTMHelpers::ShipmentHeaderElementsHelper
      # include FourKitesParsers::Helper::OtmHelpers::MondlezOTMHelpers::ShipmentHeaderElementsHelper
      VALID_REFERENCE_NUMBER_XID = ['CUSTOMER_REPORT_GROUP','HIGH_COMMODITY', 'LOADTYPE_DROP_OR_LIVE']
      SHIPMENT_GID_PREFIX = "ShipmentGid DomainName: "
      def strict_enabled?
        Settings.four_kites_common.mondelez_load_xml_parser.strict || false
      rescue => e
        FourKitesCommon::Logger.warn(self, "Could not get Settings", error: e.message)
        false
      end
 
      def parse_content_with_nokogiri
        if strict_enabled?
          Nokogiri::XML(@content) do |config|
            config.strict.noblanks
          end
        else
          Nokogiri::XML(@content) do |config|
            config.noblanks
          end
        end
      end
 
      def parse_file
        @content = @file.read.encode("utf-8", "binary", :replace => "", :undef => :replace, :invalid => :replace)
        @file.close
        xml_doc = parse_content_with_nokogiri
        xml_doc.remove_namespaces!
        transmission_body = xml_doc.xpath("//TransmissionBody")
        glog_xml_element = transmission_body.children.first
        planned_shipment = glog_xml_element.xpath("//PlannedShipment")
        shipment = planned_shipment.children.first
        @shipment = shipment
        load = new_blank_record
        pickup_stops = []
        delivery_stops = []
        @shipment_name = ""
        shipment_header = shipment.xpath("//ShipmentHeader")
        transaction_code = shipment_header.xpath("TransactionCode")
        load[0] = 'add'  # default action is add
        load[0] = 'delete' if transaction_code.present? && transaction_code.first.text =~ /D/i
        shipment.children.each do |shipment_attr_element|
          case shipment_attr_element.name
          when 'ShipmentHeader'
            begin
              shipment_header = shipment_attr_element
              shipment_header.children.each do | shipment_header_attr_element|
                case shipment_header_attr_element.name
                when 'ShipmentGid'
                  begin
                    gid = shipment_header_attr_element.children.first
                    xid = gid.children.select { |element| element.name == 'Xid'}.first
                    load[1] = xid.text
                    load[8] << get_domain_name(gid)
                  rescue Exception => e
                    FourKitesCommon::Logger.error(self, "Error parsing ShipmentGid in file #{@file_name}", error: e.message)
                  end
                when 'ServiceProviderGid'
                  parse_service_provider_gid_or_shipment_gid('ServiceProviderGid', shipment_header_attr_element)
                when 'ShipmentRefnum'
                  begin
                    parsed_shipment_ref_num = parse_shipment_ref_num(shipment_header_attr_element)
                    load[8] << "GLOG Refnum: #{parsed_shipment_ref_num[:value]}" if parsed_shipment_ref_num[:xid].in?(['GLOG']) && parsed_shipment_ref_num[:value].present?
                    load[8] << get_label(parsed_shipment_ref_num[:xid]) + ": " + parsed_shipment_ref_num[:value] if valid_load_reference_number?(parsed_shipment_ref_num)
                    # This is a landmine waiting to be stepped on
                    # load[19] = {:externalId => parsed_shipment_ref_num[:value]} if parsed_shipment_ref_num[:xid] == 'HIGH_COMMODITY'
                    @bm = parsed_shipment_ref_num[:value] if parsed_shipment_ref_num[:xid] == 'BM'
                  rescue Exception => e
                    FourKitesCommon::Logger.error(self, "Error parsing ShipmentRefnum in file #{@file_name}", error: e.message)
                  end
                when 'InternalShipmentStatus'
                  begin
                    parsed_internal_shipment_status = parse_internal_shipment_status(shipment_header_attr_element)
                    load[0] = 'delete' if parsed_internal_shipment_status[:status_type] == 'TRACK' && parsed_internal_shipment_status[:status_value] == 'TRACK_NO'
                  rescue
                    FourKitesCommon::Logger.error(self, "Error parsing InternalShipmentStatus in file #{@file_name}", error: e.message)
                  end
                when 'ShipmentName'
                  @shipment_name = shipment_header_attr_element.text
                  load[11] = @shipment_name
                end
              end
 
              parse_4K_tags shipment_header
            rescue Exception => e
              FourKitesCommon::Logger.error(self, "Error parsing ShipmentHeader in file #{@file_name}", error: e.message)
            end
          when 'ShipmentStop'
            begin
              parsed_shipment_stop = parse_shipment_stop(shipment_attr_element, shipment)
              parse_location_id(shipment_attr_element, parsed_shipment_stop[:stop])
              parse_shipment_address(shipment, parsed_shipment_stop[:stop])
              process_shipment_stops(parsed_shipment_stop, pickup_stops, delivery_stops)
            rescue Exception => e
              FourKitesCommon::Logger.error(self, "Error parsing ShipmentStop in file #{@file_name}", error: e.message)
            end
          when 'Location'
            parse_location_reference_num(shipment_attr_element)
          when 'Release'
            parse_load_level_reference1(shipment_attr_element)
          end
        end
        load[3] = pickup_stops
        load[4] = delivery_stops
        load[8] = load[8].compact.uniq
        return [load]
      end
 




      def parse_customer_id(location_ref_num, shipment, stop)
        shipment.xpath("./Location").each do |location|
          if location.xpath("./LocationGid[1]/Gid[1]/Xid[1]").try(:text) == location_ref_num
            location_tag = location.xpath("./LocationRefnum[LocationRefnumQualifierGid/Gid/Xid='CUST_HRCHY_NUM_3']/LocationRefnumValue").first.try(:text)
            get_id_value(stop, location_tag)
          end
        end
      end
 
      def get_id_value(stop, location_tag)
        if location_tag.present?
          stop[:customer] ||= {} 
          stop[:customer][:id] = location_tag if stop[:customer][:id].blank?
        end
      end
      
      def valid_load_reference_number?(parsed_shipment_ref_num)
        valid_parsed_ref_num_field?(parsed_shipment_ref_num) && parsed_shipment_ref_num[:xid].in?(VALID_REFERENCE_NUMBER_XID)
      end
 
      def valid_parsed_ref_num_field?(parsed_shipment_ref_num)
        parsed_shipment_ref_num[:xid].present? && parsed_shipment_ref_num[:value].present?
      end
 
      def parse_location_id(shipment_attr_element, stop)
        location_id = shipment_attr_element.xpath("./LocationRef/LocationGid/Gid/Xid").text
        stop[:location_id] = location_id if location_id.present?
      end
 
      def parse_shipment_address shipment, parsed_shipment_stop
        shipment.xpath("./Location").each do |location|
          if location.xpath("./LocationGid/Gid/Xid").text == parsed_shipment_stop[:location_id]
            parsed_shipment_stop[:location] = location.xpath("./LocationName").text
            parse_address location.xpath("./Address"), parsed_shipment_stop
          end
        end
      end
 
      def get_customer_id shipment_stop, stop
        if customer_id = shipment_stop.xpath('LocationId') || shipment_stop.xpath('CustomerId')
          unless customer_id.text.blank?
            stop[:customer] ||= {}
            stop[:customer][:id] = customer_id.text
          end
        end
      end
 
      def get_domain_name(gid)
        shipment_gid_domain_name = get_domain_name_from_element(gid).try(:text)
        "#{SHIPMENT_GID_PREFIX}#{shipment_gid_domain_name}" if shipment_gid_domain_name.present?
      end
    end
  end
end