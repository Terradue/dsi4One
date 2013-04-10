# ---------------------------------------------------------------------------- #
# Copyright 2010-2013, C12G Labs S.L                                           #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #

require "scripts_common"
require 'yaml'
require "CommandManager"
require "rexml/document"
require "VirtualMachineDriver"
require 'fileutils'

class DSIDriver < VirtualMachineDriver
    # -------------------------------------------------------------------------#
    # Set up the environment for the driver                                    #
    # -------------------------------------------------------------------------#
    ONE_LOCATION = ENV["ONE_LOCATION"]
    DSI_LOCATION = ENV["DSI_TOOLS_HOME"]
    DSI_ONE_CONTEXT_LOCATION = ENV["DSI_ONE_CONTEXT_LOCATION"]

    if !ONE_LOCATION
       BIN_LOCATION = "/usr/bin" 
       LIB_LOCATION = "/usr/lib/one"
       ETC_LOCATION = "/etc/one" 
       VAR_LOCATION = "/var/lib/one"
    else
       LIB_LOCATION = ONE_LOCATION + "/lib"
       BIN_LOCATION = ONE_LOCATION + "/bin" 
       ETC_LOCATION = ONE_LOCATION  + "/etc/"
       VAR_LOCATION = ONE_LOCATION + "/var/"
    end

    CONF_FILE   = ETC_LOCATION + "/dsirc"
    CHECKPOINT  = VAR_LOCATION + "/remotes/vmm/dsi/checkpoint"
    DSI_TOOLS = DSI_LOCATION + "/bin/"

    ENV['LANG'] = 'C'

    SHUTDOWN_INTERVAL = 5
    SHUTDOWN_TIMEOUT  = 500

    def initialize(host)
      
       conf  = YAML::load(File.read(CONF_FILE))
       
       # User parameters
       @user     = conf[:username]
       
       if conf[:password] and !conf[:password].empty?
          @pass  = conf[:password]
       else
          @pass="\"\""
       end
       
	   # Provider parameters
	   @provider  = conf[:provider_id]
	   @qualifier = conf[:qualifier_id]
	   
    end

    # ######################################################################## #
    #                       DSI T-SYSTEMS DRIVER ACTIONS                       #
    # ######################################################################## #

    # ------------------------------------------------------------------------ #
    # Deploy & define a VM based on its description file                       #
    # ------------------------------------------------------------------------ #
    def deploy(dfile, id)
    	
        one_id = "one-#{id}"
        time = Time.now
        
    	# Extract informations from xml template
    	xml = File.new(dfile, "r").read
    	doc = REXML::Document.new xml    	  
    	
    	# Deployment parameters  
    	cpu         = doc.elements["TEMPLATE/CPU"].text
    	memory      = doc.elements["TEMPLATE/MEMORY"].text
    	perf        = doc.elements["TEMPLATE/DSI/PERF"].text
    	network     = doc.elements["TEMPLATE/DSI/NETWORK_ID"].text
    	appliance   = doc.elements["TEMPLATE/DSI/IMAGE_ID"].text
    	description = doc.elements["TEMPLATE/DSI/DESCRIPTION"].text
    	end_date    = doc.elements["TEMPLATE/DSI/END_DATE"].text
    	delegate    = doc.elements["TEMPLATE/DSI/DELEGATE_ROLE_ID"].text
        users       = doc.elements["TEMPLATE/DSI/USERS_ID"].text
        name        = "#{one_id}-#{time.year}#{time.month}#{time.day}#{time.hour}#{time.min}"
        
        # Contextualization files
        @files      = doc.elements["TEMPLATE/DSI/FILES"].text   	 
       
        # Construct the command parameters
        auth_params       = "-u #{@user} -p #{@pass} --delegate-role #{delegate} --users #{users}"
        resource_params   = "--memory #{memory} --virtual-cpu #{cpu} --perf #{perf} --network #{network}"
        provider_params   = "--provider #{@provider} --qualifier #{@qualifier}"
        deployment_params = "--appliance #{appliance} --description #{description} --end #{end_date}"
                
        # Start the VM
        rc, info = do_action(DSI_TOOLS + "dsi-create-deployment" + " " + auth_params +
                             " " + resource_params + " " + provider_params + " " + 
                             deployment_params + " --external-ip --permanent-ip --name " + name)
                   
        if rc == false
            exit info
        end
        
        # Extract the Deployment id from DSI response        
        regex = /\[INFO\]\sDeployment\screated\swith\sid:\s(\d{1,})/
        deploy_id = info.match(regex)[1]
               
        OpenNebula.log_debug("Successfully created DSI deployment (name: #{one_id}, deploy id:#{deploy_id})")

        return deploy_id
    end

    # ------------------------------------------------------------------------ #
    # Cancels the VM                                                           #
    # ------------------------------------------------------------------------ #
    def cancel(deploy_id)
        
        auth_params = "-u #{@user} -p #{@pass}"
        
        # Destroy the VM
        rc, info = do_action(DSI_TOOLS + "dsi-stop-deployments" + " " + auth_params + " " + deploy_id) 

        exit info if rc == false

        OpenNebula.log_debug("Successfully canceled deployment #{deploy_id}.")
    end

    # ------------------------------------------------------------------------ #
    # Reboots a running VM                                                     #
    # ------------------------------------------------------------------------ #
    def reboot(deploy_id)
        
        auth_params = "-u #{@user} -p #{@pass}"
        
        # Destroy the VM
        rc, info = do_action(DSI_TOOLS + "dsi-reboot-deployments" + " " + auth_params + " " + deploy_id)

        exit info if rc == false

        OpenNebula.log_debug("Deployment #{deploy_id} successfully rebooted.")
    end

    # ------------------------------------------------------------------------ #
    # Reset a running VM                                                       #
    # ------------------------------------------------------------------------ #
    def reset(deploy_id)
        
        auth_params = "-u #{@user} -p #{@pass}"
        
        # Destroy the VM
        rc, info = do_action(DSI_TOOLS + "dsi-reboot-deployments" + " " + auth_params + " " + deploy_id)

        exit info if rc == false

        OpenNebula.log_debug("Deployment #{deploy_id} successfully reseted.")
    end

    # ------------------------------------------------------------------------ #
    # Migrate                                                                  #
    # ------------------------------------------------------------------------ #
    def migrate(deploy_id, dst_host, src_host)
        
        OpenNebula.log_debug("Action not implemented.")
    end
    
    # ------------------------------------------------------------------------ #
    # Monitor a VM                                                             #
    # ------------------------------------------------------------------------ #
    def poll(deploy_id)
        
        auth_params = "-u #{@user} -p #{@pass}"
        
        # Set the fields of interests 
        fields = "state,externalIpAddress,internalIpAddress"
               
        # Start the monitoring
        rc, info = do_action(DSI_TOOLS + "dsi-describe-deployments" + " " + auth_params + " " + deploy_id + " --fields " + fields)

        return "STATE=#{VM_STATE[:deleted]}" if rc == false

		# Extract informations from describe-deployments response        
        regex = /\[INFO\]\s\|\s(\w*)\s*\|\|\s(\w*.\w*.\w*.\w*)\s*\|\|\s(\w*.\w*.\w*.\w*)/
        
        OpenNebula.log_debug("info: #{info}")
        
        tmp = info.match(regex)
        state = tmp[1]
                        
        case state
            when "RUNNING"
                state_short = VM_STATE[:active]
            else
                state_short = VM_STATE[:unknown]
        end
        
        external_ip_addr = (tmp[2] != "null" && tmp[2]) || '-'
        internal_ip_addr = (tmp[3] != "null" && tmp[3]) || '-'
        
        # If the Deployment has the internal IP, it is running and can download the context
        if internal_ip_addr != '-'
            
            deployment_id = 'sb-dsi-' + internal_ip_addr.gsub(".", "-")
            deployment_dir = DSI_ONE_CONTEXT_LOCATION + '/' +deployment_id
            
            prepare_context(deployment_id) unless File.directory?(deployment_dir) 
        end
                    
        info = "STATE=#{state_short} EXTERNAL_IP=#{external_ip_addr} INTERNAL_IP=#{internal_ip_addr}"
    end

    # ------------------------------------------------------------------------ #
    # Restore a VM                                                             #
    # ------------------------------------------------------------------------ #
    def restore(checkpoint)
        OpenNebula.log_debug("Action not yet implemented.")
    end

    # ------------------------------------------------------------------------ #
    # Saves a VM taking a snapshot                                             #
    # ------------------------------------------------------------------------ #
    def save(deploy_id)
        # Take a snapshot for the VM
        # Destroy the VM
        rc, info = do_action(DSI_TOOLS + "dsi-create-tags" + " " + auth_params + " " + deploy_id)

        exit info if rc == false

        # Suspend VM
        # Action not implemented

    end

    # ------------------------------------------------------------------------ #
    # Shutdown a VM                                                            #
    # ------------------------------------------------------------------------ #
    def shutdown(deploy_id)
    
        cancel(deploy_id)
    end

    # ######################################################################## #
    #                          DRIVER HELPER FUNCTIONS                         #
    # ######################################################################## #

    private

    # Performs an action
    def do_action(cmd, log=true)
        rc = LocalCommand.run(cmd)

        if rc.code == 0
            return [true, rc.stdout]
        else
            err = "Error executing: #{cmd} err: #{rc.stderr} out: #{rc.stdout}"
            OpenNebula.log_error(err) if log
            return [false, rc.code]
        end
    end
    
    # Prepare a context for the Deployment
    def prepare_context(deployment_id)
                        
        # List of contextualization files
        files = @files.split(" ")               
                            
        # Creating context dir
        context_dir = 'context' 
        dest = DSI_ONE_CONTEXT_LOCATION + '/' + deployment_id + '/' + context_dir 
        FileUtils.mkdir_p dest
        
        # Copying context file
        files.each do |file|
            FileUtils.cp file, dest
        end
        
        # Creating tarball
        tar_file = 'context.tar.gz'  
        tar_dir = DSI_ONE_CONTEXT_LOCATION + '/' + deployment_id        
        rc, info = do_action("cd #{tar_dir}; tar -cf #{tar_file} #{context_dir}")            
    end
    
    # Remove the context when unnecessary
    def remove_context(deployment_id)
        # TODO
    end

end
