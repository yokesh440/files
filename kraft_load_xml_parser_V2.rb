module FourKitesParsers
  module Parser
    class KraftLoadXmlParserV2 < BaseLoadParser
      include FourKitesParsers::Parser::ParserCommon
      include FourKitesParsers::Helper::OtmHelpers::KraftOTMHelpers::ShipmentHeaderElementsHelper
      include FourKitesParsers::Helper::OtmHelpers::KraftOTMHelpers::ShipmentStopElementsHelper
      include FourKitesParsers::Helper::OtmHelpers::KraftOTMHelpers::ShipmentTagsHelper
      include FourKitesParsers::Helper::OtmHelpers::KraftOTMHelpers::OtmCommon

      COUNTRY_CODE = {"USA" => 'US', "MEX" => 'MX', "CAN" => 'CA'}


      def initialize(file_name)
        @file_name = file_name
        if @file_name.blank? || !File.exists?(@file_name)
          raise 'Invalid file'
        else
          @file = File.open(@file_name)
        end
      end

      def configurations
        {
            processLatLongOptionally: true
        }
      end

      def strict_enabled?
        Settings.four_kites_common.kraft_load_xml_parser.strict || false
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
        @content = @file.read.encode("utf-8", :replace => "", :invalid => :replace)
        @file.close
        xml_doc = parse_content_with_nokogiri
        xml_doc.remove_namespaces!
        @planned_shipment = xml_doc.xpath("//TransmissionBody/*//PlannedShipment")
        @shipment = xml_doc.xpath("//TransmissionBody/*//PlannedShipment/*[1]")
        initialize_data
        load = new_blank_record
        load[0] = 'add' # default action is add
        parse_kraft_tags load, shipment
        parse_shipment
        load[3] = pickup_stops
        load[4] = delivery_stops
        load[8] = load[8].compact.uniq
        return [load]
      end

      def parse_shipment_header(shipment_attr_element)
        shipment_header = shipment_attr_element
        shipment_header.children.each do |shipment_header_attr_element|
          case shipment_header_attr_element.name
          when 'ShipmentGid'
            @load[1] = shipment_header_attr_element.xpath("./*[1][self::Gid]/Xid[1]").text
          when 'ServiceProviderGid'
            parse_service_provider_gid_or_shipment_gid('ServiceProviderGid', shipment_header_attr_element)
          when 'ShipmentRefnum'
            parse_shipment_refnum(shipment_header_attr_element)
          when 'TransactionCode'
            @load[0] = 'delete' if shipment_header_attr_element.text == 'D'
          when 'ShipmentName'
            @shipment_name = shipment_header_attr_element.text
            @load[11] = @shipment_name
          end
        end
        parse_4K_tags shipment_header
      end



      def parse_location(shipment_attr_element)
        location_ref_nums = []
        shipment_attr_element.children.each do |location_attr_element|
          if location_attr_element.name == 'LocationRefnum'
            location_ref_nums << parse_location_ref_num(location_attr_element)
          end
        end
        location_ref_nums
      end

      def parse_location_ref_num(location_ref_num)
        parse_field_ref_num(location_ref_num, 'LocationRefnumQualifierGid', 'LocationRefnumValue')
      end


      def parse_kraft_tags load, shipment
        get_shipment_xpaths_for_tags.each do |xpath|
          if shipment.xpath(xpath).text == 'Y'
            load[5] << 'INBOUND'
            break
          end
        end
        map_release_type_gid_tags(load, shipment)
      end

      def map_release_type_gid_tags(load, shipment)
        kraft_tags = {
            "INBOUND_PURCHASE_ORDER" => "RAW_AND_PACK"
        }
        release_type_gid_tags = ["STO_PO", "SALES_ORDER"]
        release_type_gid_tags << "INBOUND_PURCHASE_ORDER" if SettingsUtil.enabled?("four_kites_common.kraft_load_xml_parser.inbound_purchase_order_tag")
        release_type_gid_tags.each do |tag_text|
          append_release_type_gid_in_load_tags(shipment, load, kraft_tags, tag_text)
        end
      end

      def parse_location_reference_num(shipment_attr_element)
        parsed_locations = parse_location(shipment_attr_element)
        parsed_locations.each do |parsed_location_ref_num|
          @load[8] << get_label(parsed_location_ref_num[:xid]) + ":" + parsed_location_ref_num[:value] if parsed_location_ref_num[:xid].in?(['BUSINESS_UNIT'])
        end
      end

      def parse_load_level_reference1(shipment_attr_element)
        release_gid = shipment_attr_element.children.detect {|child| child.name == 'ReleaseGid'}
        if release_gid.present?
          gid = get_gid_from_element(release_gid)
          if gid.present?
            xid = get_xid_from_element(gid)
            @load[8] << xid.text if xid.present?
          end
        end
      end

      def append_release_type_gid_in_load_tags(shipment, load, kraft_tags, tag_text)
        if shipment.xpath("Release/ReleaseTypeGid[Gid/Xid='#{tag_text}']").present?
          load[5] << (kraft_tags.key?(tag_text) ? kraft_tags[tag_text] : tag_text)
        end
      end

      def get_shipment_xpaths_for_tags
        ['ShipmentHeader/ShipmentRefnum[ShipmentRefnumQualifierGid/Gid/Xid="INBOUND"]/ShipmentRefnumValue', 'Release/ReleaseRefnum[ReleaseRefnumQualifierGid/Gid/Xid="INBOUND"]/ReleaseRefnumValue']
      end

      def parse_4K_tags shipment_header
        # 4K_LOAD_TAGS
        if load_tags = shipment_header.xpath('Remark[RemarkQualifierGid/Gid/Xid="4K_LOAD_TAGS"]/RemarkText')
          tags = load_tags.text.split(/:+/).delete_if {|tag| tag.blank?}
          @load[5] |= tags
        end
        # 4K_STOP_TAGS
        if stop_tags = shipment_header.xpath('Remark[RemarkQualifierGid/Gid/Xid="4K_STOP_TAGS"]/RemarkText')
          stop_tags.each do |stop_tag|
            tags = stop_tag.text.split /:+/
            # first one is stop number which is tossed
            tags.shift
            @load[5] |= tags
          end
        end
      end


      def get_customer_id shipment_stop, stop
        if customer_id = shipment_stop.xpath('CustomerId')
          unless customer_id.text.blank?
            stop[:customer] ||= {}
            stop[:customer][:id] = customer_id.text
          end
        end
      end

      def parse_4K_stop_tags shipment_stop, stop
        if stop[:sequence]
          # Stop level tags/reference number are in the ShipmentHeader
          # Since stops don't have tags, save them as a reference number
          # the tags/reference number has the stop number as the first element
          all_stop_tags = shipment_stop.xpath('../ShipmentHeader/Remark[RemarkQualifierGid/Gid/Xid="4K_STOP_TAGS"]/RemarkText')
          all_stop_tags.each do |tag_element|
            tags = tag_element.text.split /:+/
            if tags.shift == stop[:sequence]
              stop[:reference_numbers] ||= []
              stop[:reference_numbers] << tags.join(':')
            end
          end
        end
      end

      def parse_shipment_stop(shipment_stop, shipment, options = {:process_pickup => true})
        parsed_shipment_stop = {}
        stop = {:reference_numbers => []}
        stop_type = shipment_stop.children.detect {|e| e.name == 'StopType'}.text
        if @bm.present? && (stop_type != 'P' || options[:process_pickup])
          stop[:reference_numbers] = ["BM#:" + @bm]
        end
        shipment_stop.children.each do |shipment_stop_attr_element|
          case shipment_stop_attr_element.name
          when 'StopSequence'
            stop[:sequence] = shipment_stop_attr_element.text
          when 'LocationName'
            stop[:location] = shipment_stop_attr_element.text
          when 'LocationId'
            stop[:location_id] = shipment_stop_attr_element.text
          when 'Address'
            parse_address shipment_stop_attr_element, stop
          when 'StopType'
            parsed_shipment_stop[:stop_type] = shipment_stop_attr_element.text
          when 'Order'
            update_stop_reference_numbers(stop, shipment_stop_attr_element)
          when 'ShipmentStopDetail'
            shipment_unit_gid_attr = shipment_stop_attr_element.children.detect {|element| element.name == 'ShipUnitGid'}
            gid = get_gid_from_element(shipment_unit_gid_attr)
            xid = get_xid_from_element(gid)

            release_element_attr = get_release_element(xid.text) if xid.present?
            if release_element_attr.present? && (stop_type != 'P' || options[:process_pickup])
              populate_stop_reference_from_release(stop, release_element_attr)
            end
          when 'LocationRef'
            location_refnum_value = shipment_stop_attr_element.xpath("./LocationGid[1]/Gid[1]/Xid[1]").try(:text)
            stop[:location_id] = location_refnum_value
            parse_customer_id(location_refnum_value, shipment, stop) if location_refnum_value.present?
          end
        end
        parse_4K_stop_tags shipment_stop, stop

        # this needs to be after parsing any possible ShipmentStopDetail
        get_customer_id shipment_stop, stop

        parsed_shipment_stop[:stop] = stop
        if parsed_shipment_stop[:stop_type] && stop[:sequence]
          get_relevant_appointment_time(shipment_stop,
                                        shipment,
                                        stop,
                                        parsed_shipment_stop[:stop_type])
        end
        return parsed_shipment_stop
      end

      def populate_stop_reference_from_release(stop, release_element_attr)
        stop_reference_number = nil
        release_element_attr.children.each do |element|
          if element.name == 'ReleaseRefnum'
            release_refnum_qualifier_gid = element.children.detect {|child| child.name == 'ReleaseRefnumQualifierGid'}
            gid = get_gid_from_element(release_refnum_qualifier_gid)
            xid = get_xid_from_element(gid)
            if xid.present? && xid.text.in?(["CUSTOMER_REPORT_GROUP", "PO", "PREV_DELIVERY_NOTE_NUMBER"])
              release_refnum_value = element.children.detect {|child| child.name == 'ReleaseRefnumValue'}
              stop_reference_number = release_refnum_value.text if release_refnum_value.present?
              label, value = get_label(xid.text), stop_reference_number.to_s
              if label.present? && value.present?
                stop[:reference_numbers] |= [label +":" + value]
                stop[:customer] = {id: value} if label.include?("Customer Report Group")
              end
            end
          end
        end
      end

      def get_label(key)
        case key
        when 'PO'
          "PO#"
        when 'PREV_DELIVERY_NOTE_NUMBER'
          "Prev Delivery Note#"
        else
          key.gsub(/_/, ' ').titlecase #CUSTOMER_REPORT_GROUP => Customer Report Group
        end
      end

      def get_country_code(address_attr_element, country)
        gid = address_attr_element.children.first
        if COUNTRY_CODE.key?(gid.children.first.text)
          address[:country] = COUNTRY_CODE[gid.children.first.text]
        else
          address[:country] = gid.children.first.text
        end
      end


      def parse_internal_shipment_status(internal_shipment_status)
        status_type_gid = internal_shipment_status.children.select {|element| element.name == 'StatusTypeGid'}.first
        type_gid = status_type_gid.children.select {|element| element.name == 'Gid'}.first
        type_xid = type_gid.children.select {|element| element.name == 'Xid'}.first
        status_value_gid = internal_shipment_status.children.select {|element| element.name == 'StatusValueGid'}.first
        value_gid = status_value_gid.children.select {|element| element.name == 'Gid'}.first
        value_xid = value_gid.children.select {|element| element.name == 'Xid'}.first
        return {:status_type => type_xid.text, :status_value => value_xid.text}
      end

      def update_stop_reference_numbers(stop, element)
        stop[:reference_numbers] ||= []
        stop[:reference_numbers] = stop[:reference_numbers].concat([get_order_id_refnum(element), get_po_refnum(element)].compact)
      end

      def get_order_id_refnum(stop_element)
        order_id = stop_element.children.detect {|e| e.name == 'OrderID'}
        "Order ID#:" + order_id.text.to_s if order_id && order_id.text
      end

      def get_po_refnum(stop_element)
        po_number = nil
        order_refnum_elements = stop_element.children.select {|e| e.name == 'OrderRefnum'}
        order_refnum_elements.each do |element|
          qualifier_element = element.children.detect {|e| e.name == 'OrderRefnumQualifier'}
          if qualifier_element.present? && qualifier_element.text == 'PO'
            order_refnum_value_element = element.children.detect {|e| e.name == 'OrderRefnumValue'}
            if order_refnum_value_element.present? && order_refnum_value_element.text.present?
              po_number = order_refnum_value_element.text
              break
            end
          end
        end
        po_number && "PO#:" + po_number.to_s
      end

      def get_release_element(id)
        @shipment.children.each do |shipment_attr_element|
          if shipment_attr_element.name == 'Release'
            release_gid_attr = shipment_attr_element.children.detect {|element| element.name == 'ReleaseGid'}
            gid = get_gid_from_element(release_gid_attr)
            xid = get_xid_from_element(gid)
            return shipment_attr_element if xid.present? && xid.text == id
          end
        end
        return nil
      end


      def get_appointment_time_from_shipment_status shipment, sequence_no, stop_type
        # alternative syntax
        # status_code = stop_type == 'P' ? 'AA' : 'AB'
        status_code = stop_type == 'P' && 'AA' || 'AB'
        if statuses = shipment.xpath("ShipmentStatus[SSStop/SSStopSequenceNum=#{sequence_no}][StatusCodeGid/Gid/Xid='#{status_code}']")
          if statuses.count > 0 && time = statuses.last.xpath('EventDt/GLogDate')
            time.text
          else
            nil
          end
        else
          nil
        end
      end

      def get_appointment_time_from_arrival_field shipment_stop
        if arrival = shipment_stop.xpath('ArrivalTime/EventTime/PlannedTime/GLogDate')
          arrival.text
        else
          nil
        end
      end

      def get_appointment_time_from_header shipment, stop_type
        # alternative syntax
        # field_name = stop_type == 'P' ? 'StartDt' : 'EndDt'
        field_name = stop_type == 'P' && 'StartDt' || 'EndDt'
        if time = shipment.xpath("ShipmentHeader/#{field_name}/GLogDate")
          time.text
        else
          nil
        end
      end

      def get_relevant_appointment_time(shipment_stop, shipment, stop, stop_type)
        time = nil

        # Get appointment time through shipment status
        time = get_appointment_time_from_shipment_status shipment, stop[:sequence], stop_type

        # Get appointment time through Transmission/TransmissionBody/GLogXMLElement/PlannedShipment/Shipment/ShipmentStop/ArrivalTime/EventTime/PlannedTime/GLogDate
        if time.blank?
          time = get_appointment_time_from_arrival_field shipment_stop
        end

        # Get appointment time through Transmission/TransmissionBody/GLogXMLElement/PlannedShipment/ShipmentHeader/StartDt|EndDt/GLogDate
        if time.blank?
          time = get_appointment_time_from_header shipment, stop_type
          want_time = time
        else
          want_time = get_appointment_time_from_header shipment, stop_type
        end

        #get want time from StartDt for pickup and EndDt for delivery
        stop[:want_time] = DateTime.parse(want_time) unless want_time.blank?

        if time.blank?
          stop[:arrival_time] = nil
        else
          stop[:arrival_time] = DateTime.parse(time)
        end
      end

      def parse_customer_id(location_ref_num, shipment, stop)
        #sample
        #it will call parser_customer_id of mondelez_load_xml_parser
      end

      def parse_shipment
        @shipment.children.each do |shipment_attr_element|
          case shipment_attr_element.name
          when 'ShipmentHeader'
            parse_shipment_header(shipment_attr_element)
          when 'ShipmentStop'
            parsed_shipment_stop = parse_shipment_stop(shipment_attr_element, shipment, {:process_pickup => false})
            process_shipment_stops(parsed_shipment_stop, pickup_stops, delivery_stops)
          when 'Location'
            parse_location_reference_num(shipment_attr_element)
          when 'Release'
            parse_load_level_reference1(shipment_attr_element)
          end
        end
      end

    end
  end
end