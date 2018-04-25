# compare_important_tags.rb
#
# Description: Compare VMs' tags with important tags.
#    So, if a VM doesn't have imporatnt tags, the VM will be tagged with
#    "azure_important_tags/no"

# Logging 
def log(level, message)  
  @method = 'Comparing VM tags with important tags'
  $evm.log(level, "#{@method} - #{message}")  
end  

important_tags = ["azure_billingidentifier", "azure_projectidentifier", "azure_environment"]
category_name = "azure_missing_important_tags"

vms = $evm.vmdb(:vm).all
vms.each do |vm|
	next if vm.archived == true
  temp_tag_array = []
	vm_name = vm.name
  vm.tags.each do |tag|
    tag_a = tag.split('/')
    temp_tag_array << tag_a.first
	end
	
	# Are all important tags present in VM tags?
	# but programingwise it was implemented, important_tags - all tags, if it is empty it means that
	# all the important tags are there
	# when its true, it will assign "yes" to a tag category called "azure_missing_important_tags"
	# when its false, it will assign "no".
	
	if (important_tags - temp_tag_array).empty?
		tagged_with_all = "no"
		unless vm.tagged_with?(category_name,tagged_with_all)
			log(:info, "Assigning Missing Important Azure Tags: {#{category_name} => #{tagged_with_all}} to VM: #{vm.name}")
			vm.tag_assign("#{category_name}/#{tagged_with_all}")
		end
		else
			tagged_with_all = "yes"
			unless vm.tagged_with?(category_name,tagged_with_all)
				log(:info, "Assigning Missing Important Azure Tags: {#{category_name} => #{tagged_with_all}} to VM: #{vm.name}")
				vm.tag_assign("#{category_name}/#{tagged_with_all}")
			end 
	end 
end
