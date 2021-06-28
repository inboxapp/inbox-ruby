# frozen_string_literal: true

describe Nylas::RoomResource do
  it "is not creatable" do
    expect(described_class).not_to be_creatable
  end

  it "is not filterable" do
    expect(described_class).not_to be_filterable
  end

  it "is not be_updatable" do
    expect(described_class).not_to be_updatable
  end

  it "is not destroyable" do
    expect(described_class).not_to be_destroyable
  end

  it "is listable" do
    expect(described_class).to be_listable
  end

  describe "#from_json" do
    it "deserializes all the attributes successfully" do
      json = JSON.dump("object": "room_resource",
                       "email": "training-room@outlook.com",
                       "name": "Microsoft Training Room",
                       "building": "Seattle",
                       "capacity": "5",
                       "floor_name": "Office",
                       "floor_number": "2")

      label = described_class.from_json(json, api: nil)

      expect(label.object).to eql "room_resource"
      expect(label.email).to eql "training-room@outlook.com"
      expect(label.name).to eql "Microsoft Training Room"
      expect(label.building).to eql "Seattle"
      expect(label.capacity).to eql "5"
      expect(label.floor_name).to eql "Office"
      expect(label.floor_number).to eql "2"
    end
  end

  context "when getting" do
    it "makes a call to the /resources endpoint" do
      api = instance_double(Nylas::API, execute: "{}")
      resource = Nylas::Collection.new(model: described_class, api: api)

      api.execute(resource.to_be_executed)

      expect(api).to have_received(:execute).with(
        method: :get,
        path: "/resources",
        headers: {},
        query: { limit: 100, offset: 0 }
      )
    end
  end
end
