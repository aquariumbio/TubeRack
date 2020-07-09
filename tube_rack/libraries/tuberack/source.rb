# typed: false
# frozen_string_literal: true

module TubeRackHelper
  def fetch_tube_rack(tube_rack)
    show do
      title 'Get Tube Rack'
      note 'To help stay organized please get a'\
           " <b>#{tube_rack.rack_type}</b>"
      note "Make sure that the rack has #{tube_rack.rows} rows and #{tube_rack.columns} columns"
      separator
      note 'Using a small piece of tape label the <b>'\
           "#{tube_rack.rack_type}</b> with <b>#{tube_rack.id}</b>"
    end
  end

  def add_items(item_list, tube_rack)
    item_list.each { |item| tube_rack.add_item(item) }

    if tube_rack.is_a? TubeRack
      tube_rack_instructions(item_list, tube_rack)
    elsif tube_rack.is_a? StripWellRack
      show do
        note 'hey it worked thats wild'
      end
    else
      raise 'Unknown Tube Rack Class'
    end
  end

  def tube_rack_instructions(item_list, tube_rack)
    tube_rack.collection.get_non_empty.each_slice(3).to_a.each do |rc_chunk|
      show do
        title 'Place Samples into Tube Rack'
        note "Place samples tubes in the <b>#{tube_rack.rack_type}</b>"\
             ' per the table below'
        table highlight_collection_rc(tube_rack.collection, rc_chunk) { |r, c|
          tube_rack.part(r, c).id
        }
      end
    end
  end
end



class TubeRack

  TRUE_ITEM = 'true_item'.to_sym

  attr_reader :rack_type, :collection, :rows, :columns, :id

  def initialize(rack_type:, collection: nil)
    @collection = collection.nil? ? Collection.new_collection(rack_type) : collection
    @rack_type = collection.nil? ? rack_type.to_s : collection.object_type.name
    @collection.mark_as_deleted
    @rows = @collection.dimensions[0]
    @columns = @collection.dimensions[1]
    @id = @collection.id
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
  def get_strip_well(row)
    Collection.find(@collection.part(row, 0).get(TRUE_COLLECTION))
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
    part.associate(TRUE_COLLECTION, item.containing_collection) if item.is_part
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
