# frozen_string_literal: true

module Inferno
  module Sequence
    class USCore310PractitionerSequence < SequenceBase
      title 'Practitioner Tests'

      description 'Verify that Practitioner resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCPR'

      requires :token
      conformance_supports :Practitioner
      delayed_sequence

      def validate_resource_item(resource, property, value)
        case property

        when 'name'
          value = value.downcase
          value_found = can_resolve_path(resource, 'name') do |name|
            name&.text&.start_with?(value) ||
              name&.family&.downcase&.include?(value) ||
              name&.given&.any? { |given| given.downcase.start_with?(value) } ||
              name&.prefix&.any? { |prefix| prefix.downcase.start_with?(value) } ||
              name&.suffix&.any? { |suffix| suffix.downcase.start_with?(value) }
          end
          assert value_found, 'name on resource does not match name requested'

        when 'identifier'
          value_found = can_resolve_path(resource, 'identifier.value') { |value_in_resource| value_in_resource == value }
          assert value_found, 'identifier on resource does not match identifier requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      @resources_found = false

      test :resource_read do
        metadata do
          id '01'
          name 'Can read Practitioner from the server'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            Reference to Practitioner can be resolved and read.
          )
          versions :r4
        end

        skip_if_not_supported(:Practitioner, [:read])

        practitioner_id = @instance.resource_references.find { |reference| reference.resource_type == 'Practitioner' }&.resource_id
        skip 'No Practitioner references found from the prior searches' if practitioner_id.nil?

        @practitioner = validate_read_reply(
          FHIR::Practitioner.new(id: practitioner_id),
          FHIR::Practitioner
        )
        @practitioner_ary = Array.wrap(@practitioner).compact
        @resources_found = @practitioner.present?
      end

      test :unauthorized_search do
        metadata do
          id '02'
          name 'Server rejects Practitioner search without authorization'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html#behavior'
          description %(
            A server SHALL reject any unauthorized requests by returning an HTTP 401 unauthorized response code.
          )
          versions :r4
        end

        skip_if_not_supported(:Practitioner, [:search])

        @client.set_no_auth
        omit 'Do not test if no bearer token set' if @instance.token.blank?

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'name'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test :search_by_name do
        metadata do
          id '03'
          name 'Server returns expected results from Practitioner search by name'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by name on the Practitioner resource

          )
          versions :r4
        end

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'name'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Practitioner' }

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @practitioner = reply.resource.entry
          .find { |entry| entry&.resource&.resourceType == 'Practitioner' }
          .resource
        @practitioner_ary = fetch_all_bundled_resources(reply.resource)
        save_resource_ids_in_bundle(versioned_resource_class('Practitioner'), reply)
        save_delayed_sequence_references(@practitioner_ary)
        validate_search_reply(versioned_resource_class('Practitioner'), reply, search_params)
      end

      test :search_by_identifier do
        metadata do
          id '04'
          name 'Server returns expected results from Practitioner search by identifier'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by identifier on the Practitioner resource

          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        search_params = {
          'identifier': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'identifier'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)
        validate_search_reply(versioned_resource_class('Practitioner'), reply, search_params)
      end

      test :vread_interaction do
        metadata do
          id '05'
          name 'Practitioner vread interaction supported'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Practitioner vread interaction.
          )
          versions :r4
        end

        skip_if_not_supported(:Practitioner, [:vread])
        skip 'No Practitioner resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@practitioner, versioned_resource_class('Practitioner'))
      end

      test :history_interaction do
        metadata do
          id '06'
          name 'Practitioner history interaction supported'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Practitioner history interaction.
          )
          versions :r4
        end

        skip_if_not_supported(:Practitioner, [:history])
        skip 'No Practitioner resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@practitioner, versioned_resource_class('Practitioner'))
      end

      test 'Server returns the appropriate resources from the following _revincludes: Provenance:target' do
        metadata do
          id '07'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        search_params = {
          'name': get_value_for_search_param(resolve_element_from_path(@practitioner_ary, 'name'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Practitioner'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results = reply&.resource&.entry&.map(&:resource)&.any? { |resource| resource.resourceType == 'Provenance' }
        assert provenance_results, 'No Provenance resources were returned from this search'
      end

      test 'Practitioner resources associated with Patient conform to US Core R4 profiles' do
        metadata do
          id '08'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitioner'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('Practitioner')
      end

      test 'At least one of every must support element is provided in any Practitioner for this patient.' do
        metadata do
          id '09'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Practitioner resources returned from prior searches to see if any of them provide the following must support elements:

            Practitioner.identifier

            Practitioner.identifier.system

            Practitioner.identifier.value

            Practitioner.identifier

            Practitioner.name

            Practitioner.name.family

          )
          versions :r4
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information' unless @practitioner_ary&.any?
        must_support_confirmed = {}
        must_support_elements = [
          'Practitioner.identifier',
          'Practitioner.identifier.system',
          'Practitioner.identifier.value',
          'Practitioner.identifier',
          'Practitioner.name',
          'Practitioner.name.family'
        ]
        must_support_elements.each do |path|
          @practitioner_ary&.each do |resource|
            truncated_path = path.gsub('Practitioner.', '')
            must_support_confirmed[path] = true if can_resolve_path(resource, truncated_path)
            break if must_support_confirmed[path]
          end
          resource_count = @practitioner_ary.length

          skip "Could not find #{path} in any of the #{resource_count} provided Practitioner resource(s)" unless must_support_confirmed[path]
        end
        @instance.save!
      end

      test 'All references can be resolved' do
        metadata do
          id '10'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_not_supported(:Practitioner, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@practitioner)
      end
    end
  end
end
