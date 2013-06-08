module Bosh
  module Clouds
    class Docker < Bosh::Cloud

      def initialize(options)
        @agent_properties ||= options.fetch('agent', {})
        registry_properties = options.fetch('registry')
        registry_endpoint = registry_properties.fetch('endpoint')
        registry_user = registry_properties.fetch('user')
        registry_password = registry_properties.fetch('password')

        @registry = Bosh::Registry::Client.new(registry_endpoint,
                                               registry_user,
                                               registry_password)

        @docker = Docker::API.new(base_url: 'http://localhost:4243')
      end

      def current_vm_id
        nil
      end

      def create_stemcell(image_path, cloud_properties)
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            system "tar -xzf #{image_path} root.img"

          end
        end
      end

      def delete_stemcell(stemcell_id)
        not_implemented(:delete_stemcell)
      end

      def create_vm(agent_id, stemcell_id, resource_pool,
          network_spec, disk_locality = nil, environment = nil)


        result = containers.create(['/bin/sh', '-c', 'while true; do echo hello world; sleep 1; done'], stemcell_id)
        vm_id = result["Id"]


        registry_settings = initial_agent_settings(
            agent_id,
            network_spec,
            environment,
            ''
        )
        registry.update_settings(vm_id, registry_settings)

        containers.start(vm_id)


        vm_id
      end

      def delete_vm(vm_id)
        containers.stop(vm_id)
        containers.remove(vm_id)
      end

      def has_vm?(vm_id)
        containers.list.collect { |c| c['Id'] }.include?(vm_id)
      end

      def reboot_vm(vm_id)
        containers.restart(vm_id)
      end

      def set_vm_metadata(vm, metadata)
        # Nothing to do here
      end

      def configure_networks(vm_id, networks)
        #not_implemented(:configure_networks)
      end

      def create_disk(size, vm_locality = nil)
        # create dir name for volume
        #not_implemented(:create_disk)
      end

      def delete_disk(disk_id)
        # remove dir
        #not_implemented(:delete_disk)
      end

      def attach_disk(vm_id, disk_id)
        # add volume to container (have to stop then start with volume)
        #not_implemented(:attach_disk)
      end

      def snapshot_disk(disk_id, metadata={})
        # copy dir (or put volume on btrfs and snapshot?)
        #not_implemented(:snapshot_disk)
      end

      def delete_snapshot(snapshot_id)
        # delete dir or btrfs snapshot
        #not_implemented(:delete_snapshot)
      end

      def detach_disk(vm_id, disk_id)
        # stop container, restart w/o volume
        #not_implemented(:detach_disk)
      end

      def get_disks(vm_id)
        details = containers.show(vm_id)
        details['Volumes'].keys
      end

      private

      attr_reader :registry, :agent_properties, :docker

      def containers
        @containers ||= docker.containers
      end

      def initial_agent_settings(agent_id, network_spec, environment, root_device_name)
        settings = {
            "vm" => {
                "name" => "vm-#{SecureRandom.uuid}"
            },
            "agent_id" => agent_id,
            "networks" => network_spec,
            "disks" => {
                "system" => root_device_name,
                "ephemeral" => '',
                "persistent" => {}
            }
        }

        settings["env"] = environment if environment
        settings.merge(agent_properties)
      end
    end
  end
end
