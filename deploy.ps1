param(

 #The subscription id where the template will be deployed.
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 #The resource group where the template will be deployed existing or a new resource group.
 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 # If specified it will try to create a new resource group in this location. If not specified, assumes resource group is existing.
 [string]
 $resourceGroupLocation,

 # The deployment name.
 [Parameter(Mandatory=$True)]
 [string]
 $deploymentName,

 #Optional, path to the template file. Defaults to template.json
 [string]
 $templateFilePath = "template.json",
 
 #Optional, path to the parameters file. Defaults to parameters.json.If file is not found, will prompt for parameter values based on template.
 [string]
 $parametersFilePath = "parameters.json",
 
 #Optional, path to the policy file. Defaults to policy.json.
 [string]
 $policyFilePath = "policy.json"
)

<#
Using functions to : Register Resource Providers,
					 Create tags for resource group ,
					 Register policy definition and assign it to resource group level
					 Validate the content of the template
#>
#Register resource providers 
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#Create resource group tags
Function CreateTags {
Param(
        [string]$param1,
		[string]$param2,
		[string]$param3
     )
	 
 
$Tags = (Get-AzureRmResourceGroup -Name $param1).Tags;
		<#	$1 = $tags.containsKey("Environment")
		if( $1 -eq "True")
				{$Tags.Remove("Environment");
				}
			$2 = $tags.containsKey("Company")
		if( $2 -eq "True" )
				{$Tags.Remove("Company");
				}
			#>	
		$Tags += @{"Environment"="$param2"; "Company"="$param3"};
	  

Set-AzureRmResourceGroup -Name $param1 -Tag $Tags;
}

#Apply the policy template to the resource group
Function ApplyPolicy {
 Param(
		
		[string]$pol1, #resourceGroupName
		[string]$pol2,  #subscriptionId,
 		[string]$pol3,  #PolicyName,
		[string]$pol4,  #PolicyAssigment
		[string]$pol5  #policyFilePath
	)

Write-Host "Registering the policy definition and assign it to '$pol1'";
New-AzureRmPolicyDefinition -Name $pol3 -Policy $pol5;
New-AzureRmPolicyAssignment -Name $pol4 -PolicyDefinition (Get-AzureRmPolicyDefinition -Name $pol3) -Scope /subscriptions/$pol2/resourceGroups/$pol1;
}

#Validate the content of the template and parameters files.
Function ValidateTemplate {
Param(
        [string]$path1,
		[string]$path2
     )
	 	
	
$dep = (Test-AzureRmResourceGroupDeployment -ResourceGroupName test -TemplateFile $path1 -TemplateParameterFile $path2);

if ($dep.Count -eq '0'){"templates are valid , applying templates";}
	Else{"stopping the deployment, please check the templates for errors ";
		  exit;			
		}
}

#******************************************************************************
# # Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

ValidateTemplate $templateFilePath $parametersFilePath ;

# sign in
Write-Host "Logging in...";
Login-AzureRmAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

#Create the tags

Write-Host "Please choose a value for environment tag from Test/Development/Production";
$env = Read-Host "environment";
Write-Host "Please enter the name of your company.";
$comp = Read-Host "company";

CreateTags $resourceGroupName $env $comp ;


# Start the deployment
Write-Host "Starting deployment...";
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;

#Apply the Policy definition and assign it to resource group

Write-Host "Please enter the name of policy definition.";
$PolicyName = Read-Host "Policy_def";

Write-Host "Please enter the name of policy assigment.";
$PolicyAssigment = Read-Host "Policy_assigment";

<#[string]$pol1, #resourceGroupName
		[string]$pol2  #subscriptionId
 		[string]$pol3  #PolicyName,
		[string]$pol4  #PolicyAssigment
		[string]$pol5  #policyFilePath
		#>
ApplyPolicy $resourceGroupName $subscriptionId $PolicyName $PolicyAssigment $policyFilePath ;
" 	##"
" 		##"
" 			##"
" 				###"
Write-Host "					Deployment was succesful";