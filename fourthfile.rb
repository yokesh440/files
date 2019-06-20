module FourKitesParsers::Helper::OtmHelpers::ShipmentStopElementsHelper
  include FourKitesParsers::Helper::OtmHelpers::ShipmentStopElementsAdditionalHelper
        
    def parse_shipment_appointment_time(shipment_related_items, stop, parsed_shipment_stop)
    shipment_stop_attr_element = shipment_related_items[:shipment_stop_attr_element]
    case shipment_stop_attr_element.name
    when 'Appointment'
      parse_shipment_stop_appointment(stop, shipment_stop_attr_element)
    when 'ArrivalTime'
      parse_arrrival_time(shipment_stop_attr_element, stop)
    when 'AppointmentPickup', 'AppointmentDelivery'
      g_log_date = shipment_stop_attr_element.children.detect { |element| element.name == 'GLogDate'}
      stop[:arrival_time] =parse_time(g_log_date.children.first.text) if g_log_date.children.first.present? && g_log_date.children.first.text.present?
    end
  end
  
  def parse_shipment_appointment_time_1(shipment_related_items, stop, parsed_shipment_stop)
    shipment_stop_attr_element = shipment_related_items[:shipment_stop_attr_element]
    case shipment_stop_attr_element.name
    when 'Appointment'
      parse_shipment_stop_appointment(stop, shipment_stop_attr_element)
    when 'ArrivalTime'
      parse_arrrival_time(shipment_stop_attr_element, stop)
    when 'AppointmentPickup', 'AppointmentDelivery'
      g_log_date = shipment_stop_attr_element.children.detect { |element| element.name == 'GLogDate'}
      stop[:arrival_time] =parse_time(g_log_date.children.first.text) if g_log_date.children.first.present? && g_log_date.children.first.text.present?
    end
  end
        
end

a = 10
b = a +
        10
c = [ 5, 4, 
        10 ]
d = [ a ] \
        + c
print "#{a} #{b} [", c.join(" "), "] [", d.join(" "), "]\n";
# Simple for loop using a range.
for i in (1..4)
    print i," "
end
print "\n"

for i in (1...4)
    print i," "
end
print "\n"

