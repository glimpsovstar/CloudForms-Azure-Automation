# assign_azure_flavour_tag.rb
#
# Description: Assigns Azure Flavour to the VM, so it can be used for chargeback

def log(level, message)  
  @method = 'Azure Flavour Tag Assign'
  $evm.log(level, "#{@method} - #{message}")  
end  

# Check to see if the main CF tag category exists and create it if not
if ! $evm.execute('category_exists?', "azure_flavours")
        $evm.execute('category_create', :name => "azure_flavours", :single_value => true, :description=> "Azure Flavours")
end

# Get a list of all VMs in the VMDB
vms = $evm.vmdb('vm').all

# Analyse each VM
vms.each do |vm|
   # If the VM is located on Azure
	if vm.vendor == "azure"
		#if vm.name == "djoo-test2"
    # Grab the VM flavour
		vm_name = vm.name
		log(:info, "VMname is : {#{vm_name}}")
		flavour = vm.flavor.name
		log(:info, "Flavour is : {#{flavour}}")
		# flavour clean up
		flavour_name = flavour.to_s.downcase.gsub(/\W/, '_')
		flavour_name = flavour_name.gsub(/_*_/, '_')
		
		# Check to see if the CF tag exists for the VMs flavour and create it if not
		if ! $evm.execute('tag_exists?', "azure_flavours", flavour_name)
			log(:info, "Azure Flavours with : {#{flavour_name}} will be created")
			$evm.execute('tag_create', "azure_flavours", :name => flavour_name, :description => flavour, :single_value => true)
		end
		# Assign the CF tag to the VM
		unless vm.tagged_with?("azure_flavours",flavour_name)
			log(:info, "Assigning Azure Tag: azure_flavours => {#{flavour_name}} to VM: {#{vm_name}}")
			vm.tag_assign("azure_flavours/#{flavour_name}")
		end
		#end
	end
end
