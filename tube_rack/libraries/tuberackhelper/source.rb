# frozen_string_literal: true

needs 'Collection Management/CollectionDisplay'

module TubeRackHelper
  include CollectionTransfer
  include CollectionDisplay

  def show_fetch_tube_rack(tube_rack)
    show do
      title 'Get Tube Rack'
      note 'To help stay organized please get a'\
           " <b>#{tube_rack.name}</b>"
      note "Make sure that the rack has <b>at least</b> #{tube_rack.rows}"\
           " rows and #{tube_rack.columns} columns"
    end
  end

  def show_add_items(item_list, tube_rack)
    tube_rack.add_items(item_list)
    item_list.each_slice(3).to_a.each do |chunk|
      chunk.map! { |item| tube_rack.find(item) }
      show do
        title 'Place Samples into Tube Rack'
        note "Place samples tubes in the <b>#{tube_rack.name}</b>"\
            ' per the table below'
        table highlight_tube_rack_rc(tube_rack, chunk) { |r, c|
          tube_rack.part(r, c).id
        }
      end
    end
  end

  # Directions to transfer media to the collection
  # @param tube_rack [SampleRack]
  # @param media [Item]
  # @param volume [Volume]
  # @param rc_list [Array<[r,c]>] list of all locations that need media
  def show_transfer_media_to_rack(tube_rack:, media:, volume:, rc_list:)
    track_provenance(tube_rack: tube_rack,
                     media: media,
                     rc_list: rc_list)

    rc_list.group_by { |loc| loc.first }.values.each do |rc_row|
      show do
        title 'Multi Channel Pipet'
        note multichannel_pipet(volume: volume,
                           source: 'Media Reservoir',
                           destination: tube_rack.name)
        note 'Per table below'
        table highlight_tube_rack_rc(tube_rack, rc_row, check: true) { |r, c|
          tube_rack.part(r, c).id
        }
      end
    end
  end

  # Instructions to fill media reservoir
  # TODO: Not sure this belongs here
  #
  # @param media (item)
  # @param volume [Volume]
  def show_fill_reservoir(media, unit_volume, number_items)
    total_vol = { units: unit_volume[:units], qty: (unit_volume[:qty] * number_items) }
    show do
      title 'Fill Media Reservoir'
      check 'Get a media reservoir'
      check pipet(volume: total_vol,
                  source: "<b>#{media.id}</b>",
                  destination: '<b>Media Reservoir</b>')
    end
  end

  # TODO: This doesn't properly track provenence I dont think
  # Not sure this is belongs here either
  def track_provenance(tube_rack:, media:, rc_list:)
    rc_list.each do |r, c|
      to_obj = tube_rack.part(r, c)
      from_obj_map = AssociationMap.new(media)
      to_obj_map = AssociationMap.new(to_obj)
      add_provenance(from: media, from_map: from_obj_map,
                     to: to_obj, to_map: to_obj_map)
      from_obj_map.save
      to_obj_map.save
    end
  end


  def highlight_tube_rack_rc(tube_rack, rc_list, check: false, &_rc_block)
    rcx_list = rc_list.map { |r, c|
      block_given? ? [r, c, yield(r, c)] : [r, c, '']
    }
    highlight_tube_rack_rcx(tube_rack, rcx_list, check: check)
  end

  def highlight_tube_rack_rcx(tube_rack, rcx_list, check: true)
    tbl = create_collection_table(rows: tube_rack.rows,
                                  columns: tube_rack.columns,
                                  col_id: 'Tube Rack')
    highlight_rcx(tbl, rcx_list, check: check)
    tbl
  end

end
