# frozen_string_literal: true


# Factory class for instantiating `PlateLayoutGenerator`
#
# @author Devin Strickland <strcklnd@uw.edu>
class TubeRackFactory

  def self.build(item_list:, object_type:, instructions: true)
    rack = nil
    if item_list.all? { |coll| coll.collection? }
      rack = StripWellRack.new(object_type: object_type)
    elsif item_list.all? { |item| item.is_a? Item }
      rack = TubeRack.new(object_type: object_type)
    else
      raise IncompatibleObjectType, 'Incompatible Object_Type'
    end
    item_list.each { |item| rack.add_item(item) }
    rack
  end

end

class TubeRack
  TRUE_ITEM = 'true_item'.to_sym

  attr_reader :object_type, :collection, :rows, :columns, :id

  def initialize(object_type:, collection: nil)
    @collection = collection.nil? ? Collection.new_collection(object_type) : collection
    @object_type = collection.nil? ? object_type.to_s : collection.object_type.name
    @collection.mark_as_deleted
    @rows = @collection.dimensions[0]
    @columns = @collection.dimensions[1]
    @id = @collection.id
  end

  def get_non_empty
    collection.get_non_empty
  end

  def get_empty
    collection.get_empty
  end

  def dimensions
    [rows, columns]
  end

  def find(val)
    if val.is_a? Sample
      return self.find_sample(val)
    elsif val.is_a? Item
      return self.find_item(val)
    else
      raise 'not valid object to find'
    end
  end

  def find_sample(sample)
    raise 'wrong object type' unless sample.is_a Sample
    locations = []
    self.get_non_empty.each do |r, c|
      locations.push([r, c]) if self.part(r, c).sample == sample
    end
    locations
  end

  def find_item(item)
    raise 'wrong object type' unless item.is_a item
    locations = []
    self.get_non_empty.each do |r, c|
      locations.push([r, c]) if self.part(r, c) == item
    end
    locations
  end

  def empty?
    collection.empty?
  end

  def full?
    collection.full?
  end

  def next(r, c, options = {})
    collection.next(r, c, options = options)
  end

  def num_samples
    collection.num_samples
  end

  def parts
    self.get_non_empty.map { |r, c| self.part(r, c) }
  end

  def set(r, c, x)
    raise 'part must be an item' unless x.is_a? Item
    self.add_item(x, location: [r, c])
  end

  # TODO: I do not like this at all.  But the association wouldn't
  # associate items properly.  Would only return hash of item params
  # and upload wasn't working at all.
  def part(r, c)
    Item.find(@collection.part(r, c).get(TRUE_ITEM))
  end

  def add_item(item, location: nil)
    location = @collection.get_empty.first if location.nil?
    row = location[0]
    column = location[1]
    @collection.set(row,
                    column,
                    Sample.find_by_name('Generic Tube Rack'))
    @collection.part(row, column).associate(TRUE_ITEM, item.id)
    [row, column]
  end
end

class StripWellRack < TubeRack

  TRUE_COLLECTION = 'true collection'.to_sym

  def add_item(item)
    unless item.collection?
      raise IncompatibleObjectType, 'Cannot add individual'\
                                     ' Items to a Strip Well Rack' 
    end

    add_strip_well(item)
  end

  # TODO: This also feels gross to me but associations won't hold
  # the actual item
  def get_strip_well(row, col)
    Collection.find(@collection.part(row, col || 0).get(TRUE_COLLECTION))
  end

  # returns all rows that a stripwell occupies
  def find_stripwell(stripwell)
    wells = []
    get_non_empty.each do |r, c|
      wells.push([r, c]) if get_strip_well(r, c) == stripwell
    end
    wells
  end

  private

  def add_single_item(item, location:)
    row = location[0]
    column = location[1]
    @collection.set(row,
                    column,
                    Sample.find_by_name('Generic Tube Rack'))
    part = @collection.part(row, column)
    part.associate(TRUE_ITEM, item.id)
    part.associate(TRUE_COLLECTION, item.containing_collection.id) if item.is_part
    [row, column]
  end

  def add_strip_well(strip_well)
    check_dimensions(strip_well)
    items = strip_well.get_non_empty.map { |loc| strip_well.part(loc[0], loc[1]) }
    r = get_empty_row
    items.each_with_index { |item, c| add_single_item(item, location: [r, c]) }
  end

  def get_empty_row
    @rows.times do |row|
      skip = false
      @columns.times do |column| 
        next if @collection.part(row, column).nil?
        skip = true
      end
      return row unless skip
    end
    raise NoEmptyRows, 'No empty rows in Strip Well Rack'
  end

  def check_dimensions(strip_well)
    rows = strip_well.dimensions[0]
    columns = strip_well.dimensions[1]
    return unless rows > @rows || columns > @columns

    raise IncompatibleDimensions, 'Strip Well dimensions are incompatible'\
                                 ' with stripwell rack'
  end

end

class IncompatibleDimensions < ProtocolError; end
class NoEmptyRows < ProtocolError; end
class IncompatibleObjectType < ProtocolError; end
