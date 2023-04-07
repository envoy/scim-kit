# frozen_string_literal: true

RSpec.describe Scim::Kit::V2::Configuration do
  subject do
    described_class.new do |x|
      x.service_provider_configuration(location: sp_location) do |y|
        y.add_authentication(:oauthbearertoken)
        y.change_password.supported = true
      end
      x.resource_type(id: 'User', location: user_type_location) do |y|
        y.schema = Scim::Kit::V2::Schemas::USER
      end
      x.resource_type(id: 'Group', location: group_type_location) do |y|
        y.schema = Scim::Kit::V2::Schemas::GROUP
      end
      x.schema(id: 'User', name: 'User', location: user_schema_location) do |y|
        y.add_attribute(name: 'userName')
      end
    end
  end

  let(:sp_location) { FFaker::Internet.uri('https') }
  let(:user_type_location) { FFaker::Internet.uri('https') }
  let(:group_type_location) { FFaker::Internet.uri('https') }
  let(:user_schema_location) { FFaker::Internet.uri('https') }

  specify { expect(subject.service_provider_configuration.meta.location).to eql(sp_location) }
  specify { expect(subject.service_provider_configuration.authentication_schemes[0].type).to be(:oauthbearertoken) }
  specify { expect(subject.service_provider_configuration.change_password.supported).to be(true) }

  specify { expect(subject.resource_types['User'].schema).to eql(Scim::Kit::V2::Schemas::USER) }
  specify { expect(subject.resource_types['User'].id).to eql('User') }
  specify { expect(subject.resource_types['Group'].schema).to eql(Scim::Kit::V2::Schemas::GROUP) }
  specify { expect(subject.resource_types['Group'].id).to eql('Group') }

  specify { expect(subject.schemas['User'].id).to eql('User') }
  specify { expect(subject.schemas['User'].name).to eql('User') }
  specify { expect(subject.schemas['User'].meta.location).to eql(user_schema_location) }
  specify { expect(subject.schemas['User'].attributes[0].name).to eql('user_name') }

  describe '#load_from' do
    let(:base_url) { FFaker::Internet.uri('https') }
    let(:service_provider_configuration) do
      Scim::Kit::V2::ServiceProviderConfiguration.new(location: FFaker::Internet.uri('https'))
    end
    let(:schema) do
      Scim::Kit::V2::Schema.new(id: 'User', name: 'User', location: FFaker::Internet.uri('https'))
    end
    let(:resource_type) do
      x = Scim::Kit::V2::ResourceType.new(location: FFaker::Internet.uri('https'))
      x.id = 'User'
      x
    end

    def list_response(collection)
      {
        schemas: [Scim::Kit::V2::Messages::LIST_RESPONSE],
        totalResults: collection.size,
        startIndex: 1,
        itemsPerPage: collection.size,
        Resources: [collection]
      }
    end

    before do
      stub_request(:get, "#{base_url}/ServiceProviderConfig")
        .to_return(status: 200, body: service_provider_configuration.to_json)

      stub_request(:get, "#{base_url}/Schemas")
        .to_return(status: 200, body: list_response(schema.to_h).to_json)

      stub_request(:get, "#{base_url}/ResourceTypes")
        .to_return(status: 200, body: list_response(resource_type.to_h).to_json)

      subject.load_from(base_url)
    end

    specify { expect(subject.service_provider_configuration.to_h).to eql(service_provider_configuration.to_h) }
    specify { expect(subject.schemas[schema.id].to_h).to eql(schema.to_h) }
    specify { expect(subject.resource_types[resource_type.id].to_h).to eql(resource_type.to_h) }
  end
end
