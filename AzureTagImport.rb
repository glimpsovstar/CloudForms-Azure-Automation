# AzureTagImport.rb
#
# Description : Obtains Tags from Azure then imports as CloudForms tags 
#   - This is required for early version of CFME 5.8 (CFs 4.5) and 5.9 (CFs 4.6)

require 'json'  
require "active_support/core_ext"  
require 'azure-armrest'
  
# Azure Connection info is derived dynamically from CFs Provider information
@provider=$evm.vmdb(:ems).find_by_type("ManageIQ::Providers::Azure::CloudManager")
@client_id=@provider.authentication_userid
@client_key=@provider.authentication_password
@tenant_id=@provider.attributes['uid_ems']
@subscriptionid=@provider.subscription
@location=@provider.attributes['provider_region'] 

# Logging 
def log(level, message)  
  @method = 'Azure Tag import'
  $evm.log(level, "#{@method} - #{message}")  
end  

# Processes TAGs 
# First checks whether category and tag exists, and if it doesn't, category/tag will be created.
# Also, CloudForms tag has limitations of;
#   - Length of 50 chars
#   - only takes lower characters
#   - only underscores allowed
# So tags will be changed to fit into above limitations
# All other chars are converted to an underscore.
#
# The return values will be processed "category" and "tag"
def process_tags(category, category_description, single_value, tag, tag_description)
  # Convert to lower case and replace all non-word characters with underscores
  # Then, changes multiple lines underscores to single underscore.
  category_name = category.to_s.downcase.gsub(/\W/, '_')
	category_name = category_name.gsub(/_*_/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')
	tag_name = tag_name.gsub(/_*_/, '_')

  unless $evm.execute('category_exists?', category_name)
    log(:info, "Creating Category {#{category_name} => #{category_description}}")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category_description}")
  end
  unless $evm.execute('tag_exists?', category_name, tag_name)
		log(:info, "Check tag name length")
		tag_name_length = tag_name.length
		if tag_name_length > 47
			log(:info, "Tag : #{tag_name} is too long with #{tag_name_length} chars")
			tag_name = tag_name.slice(0..47)+"__"
			log(:info, "Tag was truncated to #{tag_name}")
		end
    log(:info, "Creating Tag {#{tag_name} => #{tag_description}} in Category #{category_name}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
  end
  return category_name, tag_name
end

# Obtains ALL VMs in Azure
#
# obtains Azure authentication information dynamically from above and uses it to grab VMs
conf = Azure::Armrest::Configuration.new(
	:tenant_id=>@tenant_id,
	:client_id=>@client_id,
	:client_key=>@client_key,
	:subscription_id=>@subscriptionid
)

azu_vms = Azure::Armrest::VirtualMachineService.new (conf)

# The script's assumption is that, Azure's VMs are already sync'ed to CFs
#
# Logic is that, the script will go through VM names, it will obtain 'tags' off it.
# vm.try(:tags) will ensure the case even if vm has nil tag.
azu_vms.list_all.each do |vm|
#if vm.name == "djoo-test2"
	azu_tags = vm.try(:tags)
	azu_exist = azu_tags.present?
	log(:info, "Does Azure Tags exist? {#{azu_exist}}")
    next if azu_tags.nil? 
	az_vm_name = vm.name
	cf_vm = $evm.vmdb(:vm).find_by_name("#{az_vm_name}")
	#log(:info, "CFs VM name is {#{cf_vm}}")

# since the vm.name is used, observed cases where two VMs with the same name exist.
# one in usual location, the other in archived	
# go to next if CFs VM is archived
	cf_vm_archived_info = cf_vm.archived
		next if cf_vm_archived_info == "yes"
	azu_tags.each do | key, value|
		category_name, tag_name = process_tags("azure_#{key}", "Azure Category #{key}", true, value, value)
		unless cf_vm.tagged_with?(category_name,tag_name)
			log(:info, "Assigning Azure Tag: {#{category_name} => #{tag_name}} to VM: #{az_vm_name}")
			cf_vm.tag_assign("#{category_name}/#{tag_name}")
		end
	end
#end
end
