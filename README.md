# dsi4one

## Description

The dsi4one driver is an OpenNebula add-on that provides a way to use the [T-Systems DSI](<http://www.t-systems.com/solutions/dynamic-services-for-infrastructure-computing-power-at-the-push-of-a-button/998132>) Cloud provider from the OpenNebula cloud controller. 

This work has been co-funded by the [European Space Agency (ESA)](<http://www.esa.int/ESA>). 

## Development

To contribute bug patches or new features for dsi4one, you can use the github Pull Request model. It is assumed that code and documentation are contributed under the Apache License 2.0. 

More info:
* [How to Contribute](http://opennebula.org/software:add-ons#how_to_contribute_to_an_existing_add-on)
* Support: [OpenNebula user mailing list](http://opennebula.org/community:mailinglists)
* Development: [OpenNebula developers mailing list](http://opennebula.org/community:mailinglists)
* Issues Tracking: Github issues

## Authors

* Leader: Cesare Rossi (cesare.rossi[at]terradue.com)
* Supervisor: Emmanuel Mathot (emmanuel.mathot[at]terradue.com)

## Compatibility

This add-on is compatible with OpenNebula 4.2.

## Features

Implements hybrid Cloud computing, to support Cloud bursting, with the ability to work with T-Systems DSI Cloud Provider

## Limitations

* The functionalities for snapshotting, restoring, or migration are not available with the dsi4one driver.

## Requirements

A Command Line Interface (CLI) that interacts with . The driver is made for CLIs developed for the dsi library (for example [dsi-tools](<https://github.com/Terradue/dsi-tools>)).

## Installation by RPM

This project is developed with Maven and the RPM provided with the rpm-maven-plugin (read `pom.xml`). Once you have built the project, install the package by:

    $ rpm -Uvh dsi4one.rpm
    
## Manual Installation

To manually install the Driver, you have to download the repository as a ZIP:

    $ unzip dsi4one-master.zip
    $ cd dsi4one-master
    
Copy the main driver files in the cloud controller machine:

    $ cp src/main/ruby/im_mad /var/lib/one/remotes/vmm/dsi
    $ cp src/main/ruby/im_mad /usr/lib/one/mads
    $ cp src/main/ruby/tm_mad /var/lib/one/remotes/tm/dsi

Copy the configuration driver files in the cloud controller machine:

    $ cp src/main/resources/config/im /etc/one/im_dsi
    $ cp src/main/resources/config/vmm/dsirc /etc/one/
    $ cp src/main/resources/config/vmm/vmm_exec_dsi.conf /etc/one/vmm_exec
    $ cp src/main/resources/scripts/setup /etc/one/dsi_setup

## Configuration

Configure the Opennebula installation, adding the Information Manager, Virtual Machine Manager and the Transfer Manager. It can be done adding to the file `/etc/one/oned.conf` the following lines:

    IM_MAD = [
        name       = "im_dsi",
        executable = "one_im_dsi",
        arguments  = "im_dsi/im_dsi.conf" ]

    VM_MAD = [
        name       = "vmm_dsi",
        executable = "one_vmm_sh",
        arguments  = "-t 15 -r 0 dsi",
        default    = "vmm_exec/vmm_exec_dsi.conf",
        type       = "xml" ]
        
    TM_MAD = [
        executable = "one_tm",
        arguments  = "-t 15 -d dummy,lvm,shared,qcow2,ssh,vmfs,iscsi,ceph,dsi" ]
        
Configure the provider parameters modifying properly the configuration file `/etc/one/im_dsi/im_dsi.conf` and the file `/etc/one/dsirc`:

    $ cat dsirc
    # User parameters
    :identity: "identity"
    :credential: "credential"

    # Provider parameters
    :provider: "provider-name"
    :cli: "dsi" 
    
Configure the CLI path on the Cloud Controller modifying properly the configuration file `/etc/one/vmm_exec/vmm_execrc`

    $ cat vmm_execrc
    [..]
    dsi_CLI_PATH=/path/to/drivers_cli/dsi/bin
    dsi_CONTEXT_PATH=/path/to/remote_context/dsi/iso
        
Restart the server via:

    $ service opennebula restart 

## Usage

There are two ways to setup the OpenNebula Cloud Controller (as oneadmin user): by following the Step 1-4 or using the setup script `/etc/one/dsi_setup/setup.sh`. 

###Step 1 - Setup the Cluster

Create a cluster on Opennebula, named for example 'dsi', using either the Sunstone GUI or via the following command:

    $ onecluster create dsi

###Step 2 - Setup the Datastore

Create a datastore on Opennebula, named for example 'dsi', using either Sunstone GUI or the following commands:

    $ cat ds.conf
    NAME    = dsi
    TM_MAD  = dsi
    TYPE    = SYSTEM_DS

    $ onedatastore create ds.conf


###Step 3 - Setup the Host

Create an host on Opennebula, named for example 'dsi', using either the Sunstone GUI or the following command:

    $ onehost create t-systems --im im_dsi --vm vmm_dsi --net dummy


###Step 4 - Prepare a Virtual Template

Prepare a template suitable for the dsi Driver, named for example 'dsi', using either the Sunstone GUI or the following commands:

    $ cat dsi_template.txt
    NAME="dsi"
    CONTEXT=[
        FILES=""
    ]
    DSI=[
        DELEGATE_ROLE_ID="1",
        DESCRIPTION="test",
        END_DATE="2014-05-31T00:00:00CET",
        IMAGE_ID="513",
        NETWORK_ID="22",
        PERF="1",
        USERS_ID="280" ]
        
    $ onetemplate create dsi.txt
    ID: 1

Note. The contextualisation section (CONTEXT) is optional. 

###Step 5 - Starting the Virtual Machine

Start the VM either via the Sunstone GUI or via the following command:

    $ onetemplate instantiate 1

## References

* T-Systems: http://www.t-systems.com
* dsi-tools: https://github.com/Terradue/dsi-tools
