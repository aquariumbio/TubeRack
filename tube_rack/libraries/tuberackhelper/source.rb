# frozen_string_literal: true

needs 'Collection Management/CollectionTransfer'
needs 'Collection Management/CollectionDisplay'

module TubeRackHelper
  include CollectionTransfer
  include CollectionDisplay

  def show_fetch_tube_rack(tube_rack)
    show do
      title 'Get Tube Rack'
      note 'To help stay organized please get a'\
           " <b>#{tube_rack.object_type}</b>"
      note "Make sure that the rack has #{tube_rack.rows} rows and #{tube_rack.columns} columns"
      separator
      note 'Using a small piece of tape label the <b>'\
           "#{tube_rack.object_type}</b> with <b>#{tube_rack.id}</b>"
    end
  end

  def show_populate_tube_rack(item_list, tube_rack)
    item_list.each_slice(3).to_a.each do |chunk|
      chunk.map! { |item| tube_rack.find(item) }
      show do
        title 'Place Samples into Tube Rack'
        note "Place samples tubes in the <b>#{tube_rack.object_type}</b>"\
            ' per the table below'
        table highlight_collection_rc(tube_rack.collection, chunk) { |r, c|
        tube_rack.part(r, c).id
        }
      end
    end
  end

  def show_populate_stripwell_rack(stripwell_list, stripwell_rack)
    rcx_list = []
    stripwell_list.each do |stripwell|
      sub_list = stripwell_rack.find_stripwell(stripwell)
      sub_list.each do |loc|
        loc.push(stripwell.id.to_s)
        rcx_list.push(loc)
      end
    end

    show do
      title 'Place Stripwells into Stripwell Rack'
      note "Carefully place stripwells into <b>#{stripwell_rack.object_type}</b>"\
           ' per the table below'
      note 'Make sure that stripwell number 1 is <b>ALWAYS</b> in column 1'
      table highlight_collection_rcx(stripwell_rack.collection, rcx_list)
    end
  end

  def show_add_items(item_list, tube_rack)
    if tube_rack.is_a? StripWellRack
      show_populate_stripwell_rack(item_list, tube_rack)
    elsif tube_rack.is_a? TubeRack
      show_populate_tube_rack(item_list, tube_rack)
    else
      raise 'Unknown Tube Rack Class'
    end
  end

  # Directions to transfer media to the collection
  # @param sample_rack [SampleRack]
  # @param media [Item]
  # @param volume [Volume]
  # @param rc_list [Array<[r,c]>] list of all locations that need media
  def transfer_media_to_rack(sample_rack:, media:, volume:, rc_list:)
    total_vol = { units: volume[:units], qty: (volume[:qty] * rc_list.length) }
    fill_reservoir(media, total_vol)

    rc_list.group_by { |loc| loc.first }.values.each do |rc_row|
      association_map = []
      rc_row.each { |r, c| association_map.push({ to_loc: [r, c] }) }
      track_provenance(sample_rack: sample_rack, media: media, rc_list: rc_list)
      multichannel_item_to_collection(to_collection: sample_rack.collection,
                                      source: "media reservoir",
                                      volume: volume,
                                      association_map: association_map)
    end
  end

  # Instructions to fill media reservoir
  # TODO: Not sure this belongs here
  #
  # @param media (item)
  # @param volume [Volume]
  def fill_reservoir(media, volume)
    show do
      title 'Fill Media Reservoir'
      check 'Get a media reservoir'
      check pipet(volume: volume,
                  source: "<b>#{media.id}</b>",
                  destination: '<b>Media Reservoir</b>')
    end
  end

  # TODO: This doesn't properly track provenence I dont think
  # Not sure this is belongs here either
  def track_provenance(sample_rack:, media:, rc_list:)
    rc_list.each do |r, c|
      to_obj = sample_rack.part(r, c)
      from_obj_map = AssociationMap.new(media)
      to_obj_map = AssociationMap.new(to_obj)
      add_provenance(from: media, from_map: from_obj_map,
                     to: to_obj, to_map: to_obj_map)
      from_obj_map.save
      to_obj_map.save
    end
  end
end
