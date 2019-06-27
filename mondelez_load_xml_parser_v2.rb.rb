module FourKitesParsers
  module Parser
    class MondelezLoadXmlParserV2 < KraftLoadXmlParser
      include FourKitesParsers::Parser::ParserCommon
      VALID_REFERENCE_NUMBER_XID = ['CUSTOMER_REPORT_GROUP', 'HIGH_COMMODITY', 'LOADTYPE_DROP_OR_LIVE']
      SHIPMENT_GID_PREFIX = "ShipmentGid DomainName: "

      def strict_enabled?
        SettingsUtil.enabled?("four_kites_common.mondelez_load_xml_parser.strict.enabled")
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
        @planned_shipment = xml_doc.xpath("//TransmissionBody/*//PlannedShipment")
        @shipment = xml_doc.xpath("//TransmissionBody/*//PlannedShipment/*[1]")
        @load = new_blank_record
        @pickup_stops = []
        @delivery_stops = []
        @shipment_name = ""
        shipment_header = @shipment.xpath("//ShipmentHeader")
        transaction_code = shipment_header.xpath("TransactionCode")
        @load[0] = 'add' # default action is add
        @load[0] = 'delete' if transaction_code.present? && transaction_code.first.text =~ /D/i
        parse_shipment
        @load[3] = @pickup_stops
        @load[4] = @delivery_stops
        @load[8] = @load[8].compact.uniq
        return [@load]
      end

      def parse_shipment
        begin
          @shipment.children.each(&method(:method_name1))
        rescue Exception => e
          FourKitesCommon::Logger.error(self, "Error parsing the file #{@file_name}", error: e.message)
        end
      end

      def method_name1(shipment_attr_element)
        case shipment_attr_element.name
        when 'ShipmentHeader'
          parse_shipment_header(shipment_attr_element)
        when 'ShipmentStop'
          parsing_shipment_stop(shipment_attr_element)
        when 'Location'
          parse_location_reference_num(shipment_attr_element)
        when 'Release'
          parse_load_level_reference(shipment_attr_element)
        end
      end

      def parse_load_level_reference(shipment_attr_element)
        release_gid = shipment_attr_element.children.detect {|child| child.name == 'ReleaseGid'}
        # if release_gid.present?
        return if release_gid.blank?
        gid = get_gid_from_element(release_gid)
        if gid.present?
              xid = get_xid_from_element(gid)
              @load[8] << xid.text if xid.present?
        end
      end


      def parse_location_reference_num(shipment_attr_element)
        parsed_locations = parse_location(shipment_attr_element)
        parsed_locations.each do |parsed_location_ref_num|
          @load[8] << get_label(parsed_location_ref_num[:xid]) + ":" + parsed_location_ref_num[:value] if parsed_location_ref_num[:xid].in?(['BUSINESS_UNIT'])
        end
      end

      def parsing_shipment_stop(shipment_attr_element)
        parsed_shipment_stop = parse_shipment_stop(shipment_attr_element, @shipment)
        parse_location_id(shipment_attr_element, parsed_shipment_stop[:stop])
        parse_shipment_address(@shipment, parsed_shipment_stop[:stop])
        process_shipment_stops(parsed_shipment_stop, @pickup_stops, @delivery_stops)
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

      def parse_shipment_address(shipment, parsed_shipment_stop)
        shipment.xpath("./Location").each do |location|
          if location.xpath("./LocationGid/Gid/Xid").text == parsed_shipment_stop[:location_id]
            parsed_shipment_stop[:location] = location.xpath("./LocationName").text
            parse_address location.xpath("./Address"), parsed_shipment_stop
          end
        end
      end

      def get_customer_id shipment_stop, stop
        if customer_id = shipment_stop.xpath('LocationId') || shipment_stop.xpath('CustomerId')
          return if customer_id.text.blank?
            stop[:customer] ||= {}
            stop[:customer][:id] = customer_id.text
          end
      end

      def get_domain_name(gid)
        shipment_gid_domain_name = get_domain_name_from_element(gid).try(:text)
        "#{SHIPMENT_GID_PREFIX}#{shipment_gid_domain_name}" if shipment_gid_domain_name.present?
      end

      def parse_shipment_header(shipment_attr_element)
        shipment_attr_element.children.each(&method(:method_name2))
        parse_4K_tags @load,shipment_attr_element
      end


      def parse_shipment_refnum(shipment_header_attr_element)
        parsed_shipment_ref_num = parse_shipment_ref_num(shipment_header_attr_element)
        @load[8] << "GLOG Refnum: #{parsed_shipment_ref_num[:value]}" if parsed_shipment_ref_num[:xid].in?(['GLOG']) && parsed_shipment_ref_num[:value].present?
        @load[8] << get_label(parsed_shipment_ref_num[:xid]) + ": " + parsed_shipment_ref_num[:value] if valid_load_reference_number?(parsed_shipment_ref_num)
        @bm = parsed_shipment_ref_num[:value] if parsed_shipment_ref_num[:xid] == 'BM'
      end


      def method_name2(shipment_header_attr_element)
        case shipment_header_attr_element.name
        when 'ShipmentGid'
          @load[1] = shipment_header_attr_element.xpath("./*[1][self::Gid]/Xid[1]").text
          gid = shipment_header_attr_element.children.first
          @load[8] << get_domain_name(gid)
        when 'ServiceProviderGid'
          gid = shipment_header_attr_element.children.first
          xid = gid.children.select {|element| element.name == 'Xid'}.first
          @load[2] = xid.text
        when 'ShipmentRefnum'
          parse_shipment_refnum(shipment_header_attr_element)
        when 'InternalShipmentStatus'
          parsed_internal_shipment_status = parse_internal_shipment_status(shipment_header_attr_element)
          @load[0] = 'delete' if parsed_internal_shipment_status[:status_type] == 'TRACK' && parsed_internal_shipment_status[:status_value] == 'TRACK_NO'
        when 'ShipmentName'
          @shipment_name = shipment_header_attr_element.text
          @load[11] = @shipment_name
        end
      end

    end
  end
end
