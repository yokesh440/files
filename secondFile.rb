message_type = 'EXPIRE_TRUCK_AVAILABILITY'
puts "hello all"
# Add the strings before and after around each parm and print
def surround(before, after, *items)
    items.each { |x| print before, x, after, "\n" }
end

surround('[', ']', 'this', 'that', 'the other')
print "\n"

surround('<', '>', 'Snakes', 'Turtles', 'Snails', 'Salamanders', 'Slugs',
        'Newts')
print "\n"

def boffo(a, b, c, d)
    print "a = #{a} b = #{b}, c = #{c}, d = #{d}\n"
end

# Use * to adapt between arrays and arguments
a1 = ['snack', 'fast', 'junk', 'pizza']
a2 = [4, 9]
boffo(*a1)
boffo(17, 3, *a2)

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

# Running through a list (which is what they do).
items = [ 'Mark', 12, 'goobers', 18.45 ]
for it in items
    print it, " "
end
print "\n"

# Go through the legal subscript values of an array.
for i in (0...items.length)
    print items[0..i].join(" "), "\n"
end
